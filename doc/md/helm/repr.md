# Repr


``repr`` is our general-purpose pretty-printer.


This is undergoing a huge refactor to make it iterable, so it yields one
line at a time and won't get hung up on enormous tables.


Currently we yield most things, and are working our way toward providing an
iterator that itself returns one line at a time until it reaches the end of
the repr.


#### imports

```lua
local core = require "singletons/core"
string.lines = core.lines
table.isarray = core.isarray
table.keys  = core.keys
local C = require "singletons/color"

local Token = require "helm/token"
local coro = coroutine
```
#### setup

```lua

local repr = {}

```
### anti_G

In order to provide names for values, we want to trawl through ``_G`` and
acquire them.  This table is from value to key where ``_G`` is key to value,
hence, ``anti_G``.

```lua
local anti_G = { _G = "_G" }
```

Now to populate it:


### repr.allNames()

Ransacks ``_G`` looking for names to put on things.


To really dig out a good name for metatables we're going to need to write
some kind of reflection function that will dig around in upvalues to find
local names for things.


#### tie_break(old, new)

A helper function to decide which name is better.

```lua
local function tie_break(old, new)
   return #old > #new
end

local function addName(t, aG, pre)
   pre = pre or ""
   aG = aG or anti_G
   if pre ~= "" then
      pre = pre .. "."
   end
   for k, v in pairs(t) do
      local T = type(v)
      if (T == "table") then
         local key = pre ..
            (type(k) == "string" and k or "<" .. tostring(k) .. ">")
         if not aG[v] then
            aG[v] = key
            if not (pre == "" and k == "package") then
               addName(v, aG, key)
            end
         else
            local kv = aG[v]
            if tie_break(kv, key) then
               -- quadradic lol
               aG[v] = key
               addName(v, aG, key)
            end
         end
         local _M = getmetatable(v)
         local _M_id = _M and "⟨" .. key.. "⟩" or ""
         if _M then
            if not aG[_M] then
               aG[_M] = _M_id
               addName(_M, aG, _M_id)
            else
               local aG_M_id = aG[_M]
               if tie_break(aG_M_id, _M_id) then
                  aG[_M] = _M_id
                  addName(_M, aG, _M_id)
               end
            end
         end
      elseif T == "function" or
         T == "thread" or
         T == "userdata" then
         aG[v] = pre .. k
      end
   end
   return aG
end
repr.addName = addName
```
#### repr.allNames(), repr.clearNames()

The trick here is that we scan ``package.loaded`` after ``_G``, which gives
better names for things.

```lua
function repr.allNames(tab)
   tab = tab or _G
   return addName(package.loaded, addName(tab))
end

function repr.clearNames()
   anti_G = {_G = "_G"}
   return anti_G
end
```
### tabulator

This is fundamentally [[Tim Caswell's][https://github.com/creationix]] code.


I've dressed it up a bit. Okay, a lot.

```lua

local SORT_LIMIT = 500  -- This won't be necessary #todo remove

local coro = coro or coroutine

local yield, wrap = assert(coro.yield), assert(coro.wrap)

local concat, insert, remove = assert(table.concat),
                               assert(table.insert),
                               assert(table.remove)

local function _keysort(a, b)
   if (type(a) == "string" and type(b) == "string")
      or (type(a) == "number" and type(b) == "number") then
      return a < b
   elseif type(a) == "number" and type(b) == "string" then
      return true
   elseif type(a) == "string" and type(b) == "number" then
      return false
   else
      return false
   end
end
```
### _yieldReprs(tab, window, c)

I want to deliver ``__repr``s from inside the funky coroutine brew,
because, well, because. ``ts`` is meant to be general.


I also want a lot of flexibility in how reprs are written, so we need to
handle several cases.


We're going to start with returning a string, and returning an iterator.


I might get around to returning tables with tokens in them and other intel,
I might not; I do have plans that are broader than merely writing an
incredibly intricate repl.

```lua

local hasmetamethod = assert(core.hasmetamethod)
local lines = assert(string.lines)

local function _yieldReprs(tab, window, c)
   local _repr = hasmetamethod("repr", tab)
   assert(c, "must have a value for c")
   assert(_repr, "failed to retrieve repr metamethod")
   local repr = _repr(tab, window, c)
   if type(repr) == "string" then
      repr = lines(repr)
   end
   if type(repr) ~= "function" then
      error("__repr must return a string or a function returning lines,\
         got a " .. type(repr))
   end
   for line, len in repr do
      len = len or #line
      yield(Token(line, c.no_color, { event = "repr_line", total_disp = len }))
   end
end

```
### name_for(value, c, hint)

Generates a simple, name-like representation of ``value``. For simple types
(strings, numbers, booleans, nil) this is the stringified value itself.
For tables, functions, etc. attempts to retrieve a name from anti_G, falling
back to generating a name from the hash if none is found.


Lots of small, nice things in this one.

```lua

local sub, find = assert(string.sub), assert(string.find)

local function _rawtostring(val)
   local ts
   if type(val) == "table" then
      -- get metatable and check for __tostring
      local M = getmetatable(val)
      if M and M.__tostring then
         -- cache the tostring method and put it back
         local __tostring = M.__tostring
         M.__tostring = nil
         ts = tostring(val)
         M.__tostring = __tostring
      end
   end
   if not ts then
      ts = tostring(val)
   end
   return ts
end

local function name_for(value, c, hint)
   local str
   -- Hint provides a means to override the "type" of the value,
   -- to account for cases more specific than mere type
   local typica = hint or type(value)
   -- Start with the color corresponding to the type--may be overridden below
   local color = c[typica]
   local cfg = {}

   -- Value types are generally represented by their tostring()
   if typica == "string"
      or typica == "number"
      or typica == "boolean"
      or typica == "nil" then
      str = tostring(value)
      if typica == "string" then
         cfg.wrappable = true
      elseif typica == "boolean" then
         color = value and c["true"] or c["false"]
      end
      return Token(str, color, cfg)
   end

   -- For other types, start by looking for a name in anti_G
   if anti_G[value] then
      str = anti_G[value]
      if typica == "thread" then
         -- Prepend coro: even to names from anti_G to more clearly
         -- distinguish from functions
         str = "coro:" .. str
      end
      return Token(str, color, cfg)
   end

   -- If not found, construct one starting with the tostring()
   str = _rawtostring(value)
   if typica == "metatable" then
      str = "⟨" .. "mt:" .. sub(str, -6) .. "⟩"
   elseif typica == "table" then
      str = "t:" .. sub(str, -6)
   elseif typica == "function" then
      local f_label = sub(str,11)
      str = sub(f_label,1,5) == "built"
                and f_label
                or "f:" .. sub(str, -6)
   elseif typica == "thread" then
      str = "coro:" .. sub(str, -6)
   elseif typica == "userdata" then
      local name_end = find(str, ":")
      if name_end then
         str = sub(str, 1, name_end - 1)
      end
   end

   return Token(str, color, cfg)
end

```
### tabulate(tab, window, c, depth, cycle)

Returns an iterator that produces Tokens representing pieces of a table,
recursively, one at a time. Implemented internally as a coroutine.

```lua
local function yield_name(...) yield(name_for(...)) end

local isarray, table_keys, sort = assert(table.isarray),
                                  assert(table.keys),
                                  assert(table.sort)

local function _tabulate(tab, window, c, depth, cycle)
   cycle = cycle or {}
   depth = depth or 0
   if type(tab) ~= "table"
      or depth > C.depth
      or cycle[tab] then
      yield_name(tab, c)
      return nil
   end
   -- __repr gets special treatment:
   -- We want to use the __repr method if and only if it is on the
   -- metatable.
   if hasmetamethod("repr", tab) and (not rawget(tab, "__repr")) then
      _yieldReprs(tab, window, c)
      return nil
   end
   -- add non-__repr'ed tables to cycle
   cycle[tab] = true

   -- Okay, we're repring the body of a table of some kind
   -- Check to see if this is an array
   local is_array = isarray(tab)
   -- And print an open brace
   yield(Token("{ ", c.base, { event = is_array and "array" or "map" }))

   -- if we have a metatable, get it first
   local _M = getmetatable(tab)
   if _M then
      if cycle[_M] then
         yield(Token("⟨", c.metatable))
      end
      yield_name(_M, c, "metatable")
      if cycle[_M] then
         yield(Token("⟩ ", c.metatable))
      end
      -- Skip printing the metatable altogether if it's going to end up
      -- represented by its name, since we just printed that.
      if depth < C.depth and not cycle[_M] then
         yield(Token(" → ", c.base))
         yield(Token("⟨", c.metatable))
         _tabulate(_M, window, c, depth + 1, cycle)
         yield(Token("⟩ ", c.metatable, { event = "sep"}))
      else
         yield(Token(" ", c.no_color, { event = "sep" }))
      end
   end

   if is_array then
      for i, val in ipairs(tab) do
         if i ~= 1 then yield(Token(", ", c.base, {event = "sep"})) end
         _tabulate(val, window, c, depth + 1, cycle)
      end
   else
      local keys = table_keys(tab)
      if #keys <= SORT_LIMIT then
         sort(keys, _keysort)
      end
      for i, key in ipairs(keys) do
         if i ~= 1 then yield(Token(", ", c.base, {event = "sep"})) end
         local val = tab[key]
         if type(key) == "string" and key:find("^[%a_][%a%d_]*$") then
            -- legal identifier, display it as a bareword
            yield_name(key, c, "field")
         else
            -- arbitrary string or other type, wrap with braces and repr it
            yield(Token("[", c.base))
            -- We want names or hashes for any lvalue table
            yield_name(key, c)
            yield(Token("]", c.base))
         end
         yield(Token(" = ", c.base))
         _tabulate(val, window, c, depth + 1, cycle)
      end
   end
   yield(Token(" }", c.base, {event = "end"}))
   return nil
end

local function tabulate(tab, window, c)
   return wrap(function()
      local success, result = pcall(_tabulate, tab, window, c)
      if not success then
         local err_lines = collect(lines, tostring(result))
         err_lines[1] = "error in __repr: " .. err_lines[1]
         for _, line in ipairs(err_lines) do
            yield(Token(line, c.alert, { event = "repr_line" }))
         end
      end
   end)
end

```
### repr.lineGen(tab, disp_width), repr.lineGenBW(tab, disp_width)

Public facades for ``lineGen``, supplying the appropriate color table
and a default width.

```lua

local Composer = require "helm/composer"

function repr.lineGen(tab, disp_width, color)
   color = color or C.color
   local generator = Composer(tabulate)
   return generator(tab, disp_width, color)
end

function repr.lineGenBW(tab, disp_width)
   return repr.lineGen(tab, disp_width, C.no_color)
end

```
### repr.ts(val, [disp_width])

Returns a representation of the value in black-and-white.


Intended as a drop-in replacement for ``tostring()``, which unpacks tables and
provides names, presuming that ``anti_G`` has been populated.

```lua
function repr.ts(val, disp_width)
   local phrase = {}
   for line in repr.lineGen(val, disp_width, C.no_color) do
      phrase[#phrase + 1] = line
   end
   return concat(phrase, "\n")
end
```
### repr.ts_color(val, [disp_width, [color]])

A ``tostring`` which uses ANSI colors.  Optional arguments are the allowed
width of lines, and a color table.

```lua
function repr.ts_color(val, disp_width, color)
   local phrase = {}
   color = color or C.color
   for line in repr.lineGen(val, disp_width, color) do
      phrase[#phrase + 1] = line
   end
   return concat(phrase, "\n")
end
```
### cdata pretty-printing

Note: the reflect library appears to be broken for LuaJIT 2.1 so we're
not going to use it.


I'm leaving in the code for now, because I'd like to repair and use it...


lol

#Todo fix
yielding multiple tokens in this case.

```lua
local function c_data(value, str, phrase)
   --local meta = reflect.getmetatable(value)
   yield(str, #str)
   --[[
   if meta then
      yield(c.base " = ", 3)
      yield_name(meta)
   end
   --]]
end
```
```lua
return repr
```
