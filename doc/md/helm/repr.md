# Repr


``repr`` is our general-purpose pretty-printer.


This is undergoing a huge refactor to make it iterable, so it yields one
line at a time and won't get hung up on enormous tables.


Currently we yield most things, and are working our way toward providing an
iterator that itself returns one line at a time until it reaches the end of
the repr.


#### imports

```lua
local a = require "singletons/anterm"

local core = require "singletons/core"

local C = require "singletons/color"
```
#### setup

```lua

local repr = {}

local hints = C.color.hints

local c = C.color
```
### anti_G

In order to provide names for values, we want to trawl through ``_G`` and
acquire them.  This table is from value to key where ``_G`` is key to value,
hence, ``anti_G``.

```lua
local anti_G = { _G = "_G" }
```

Now to populate it:


### C.allNames()

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
               addName(_M, aG, _M_id)
               aG[_M] = _M_id
            else
               local aG_M_id = aG[_M]
               if tie_break(aG_M_id, _M_id) then
                  addName(_M, aG, _M_id)
                  aG[_M] = _M_id
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
local ts, ts_coro

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
### _yieldReprs(tab, disp)

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

local function _yieldReprs(tab, phrase)
   local _repr = hasmetamethod("repr", tab)
   assert(c, "must have a value for c")
   assert(_repr, "failed to retrieve repr metamethod")
   local repr = _repr(tab, phrase, c)
   local yielder
   if type(repr) == "string" then
      yielder = lines(repr)
   else
      yielder = repr
   end
   while true and type(yielder) == 'function' do
      local line, len = yielder()
      if line ~= nil then
         len = len or #line
         -- Yield something enough like a token for lineGen to notice
         -- that it's special and just pass the string through.
         yield { event = "repr_line",
                 total_disp = len,
                 line = line }
      else
         break
      end
   end
end

```
### make_token(str, color[, event[, is_string]])

Assembles a "token" structure from the given string, color value,
and optional event name. The structure looks like:

```lua-example
{
   "f", "o", "o", "\\n",
   color = c.string,
   disps = { 1, 1, 1, 2 },
   total_disp = 5,
   escapes = { ["\\n"] = true },
   event = {"array", "map", "sep", "end", "repr_line"} -- One of those, or nil
}
```

If ``is_string`` is truthy, performs some additional steps applicable
only to strings:
# Converts nonprinting characters and quotation marks to their escaped forms,
  with the ``escapes`` property indicating which characters this has been done to.
# Wraps the string in (un-escaped) quotation marks if it consists entirely of
  space characters (or is empty).

```lua

local byte, codepoints, find, format, match, sub = assert(string.byte),
                                                   assert(string.codepoints),
                                                   assert(string.find),
                                                   assert(string.format),
                                                   assert(string.match),
                                                   assert(string.sub)

local escapes_map = {
   ['"'] = '\\"',
   ["'"] = "\\'",
   ["\a"] = "\\a",
   ["\b"] = "\\b",
   ["\f"] = "\\f",
   ["\n"] = "\\n",
   ["\r"] = "\\r",
   ["\t"] = "\\t",
   ["\v"] = "\\v"
}

local function make_token(str, color, event, is_string)
   local token = codepoints(str)
   token.color = color
   token.event = event
   token.is_string = is_string
   token.disps = {}
   token.escapes = {}
   token.total_disp = 0
   for i, frag in ipairs(token) do
      -- For now, assume that all codepoints occupy one cell.
      -- This is wrong, but *usually* does the right thing, and
      -- handling Unicode properly is hard.
      token.disps[i] = 1
      if is_string and (escapes_map[frag] or find(frag, "%c")) then
         frag = escapes_map[frag] or format("\\x%x", byte(frag))
         token[i] = frag
         -- In the case of an escape, we know all of the characters involved
         -- are one-byte, and each occupy one cell
         token.disps[i] = #frag
         token.escapes[frag] = true
      end
      token.total_disp = token.total_disp + token.disps[i]
   end
   if is_string and find(str, '^ *$') then
      insert(token, 1, '"')
      insert(token.disps, 1, 1)
      insert(token, '"')
      insert(token.disps, 1)
      token.total_disp = token.total_disp + 2
   end
   return token
end

local function yield_token(...)
   yield(make_token(...))
end

```
### token_tostring(token)

Flattens a token structure back down to a simple string, including coloring sequences.

```lua

local function token_tostring(token)
   local output = {}
   for i, frag in ipairs(token) do
      if token.escapes[frag] then
         frag = c.stresc .. frag .. token.color
      elseif token.err and token.err[i] then
         frag = c.alert .. frag .. token.color
      end
      output[i] = frag
   end
   return token.color(concat(output))
end

```
### split_token(token, max_disp)

Splits a token such that the first part occupies no more than ``max_disp`` cells.
Returns two tokens.

```lua

local function split_token(token, max_disp)
   local disp_so_far = 0
   local split_index
   for i, disp in ipairs(token.disps) do
      if disp_so_far + disp > max_disp then
         split_index = i - 1
         break
      end
      disp_so_far = disp_so_far + disp
   end
   local first, rest = { disps = {} }, { disps = {} }
   -- Copy over the properties in common.
   for _,k in ipairs({"color", "event", "escapes"}) do
      first[k] = token[k]
      rest[k] = token[k]
   end
   for i = 1, split_index do
      first[i]       = token[i]
      first.disps[i] = token.disps[i]
   end
   first.total_disp = disp_so_far
   for i = split_index + 1, #token do
      rest[i - split_index]       = token[i]
      rest.disps[i - split_index] = token.disps[i]
   end
   rest.total_disp = token.total_disp - disp_so_far
   return first, rest
end

```
### _tabulate(tab, depth, cycle, phrase)

This ``yield()s`` pieces of a table, recursively, one at a time.

```lua
local function O_BRACE(event) yield_token("{ ", c.base, event) end
local function C_BRACE()      yield_token(" }", c.base, "end") end
local function COMMA()        yield_token(", ", c.base, "sep") end
local function EQUALS()       yield_token(" = ", c.base)       end

local isarray, table_keys, sort = assert(table.isarray), assert(table.keys), assert(table.sort)

local function _tabulate(tab, depth, cycle, phrase)
   cycle = cycle or {}
   depth = depth or 0
   if type(tab) ~= "table" then
      ts_coro(tab, nil, phrase)
      return nil
   end
   if depth > C.depth or cycle[tab] then
      ts_coro(tab, "tab_name", phrase)
      return nil
   end
   cycle[tab] = true
   -- __repr gets special treatment:
   -- We want to use the __repr method if and only if it is on the
   -- metatable.
   if hasmetamethod("repr", tab) and (not rawget(tab, "__repr")) then
      _yieldReprs(tab, phrase)
      return nil
   end

   -- if we have a metatable, get it first
   local _M = getmetatable(tab)
   if _M then
      ts_coro(_M, "mt", phrase)
      EQUALS()
      _tabulate(_M, depth + 1, cycle, phrase)
   end

   -- Okay, we're repring the body of a table of some kind
   -- Check to see if this is an array
   local is_array = isarray(tab)
   -- And print an open brace
   O_BRACE(is_array and "array" or "map")

   if is_array then
      for i, val in ipairs(tab) do
         if i ~= 1 then COMMA() end
         _tabulate(val, depth + 1, cycle, phrase)
      end
   else
      local keys = table_keys(tab)
      if #keys <= SORT_LIMIT then
         sort(keys, _keysort)
      end
      for i, key in ipairs(keys) do
         if i ~= 1 then COMMA() end
         local val = tab[key]
         if type(key) == "string" and key:find("^[%a_][%a%d_]*$") then
            -- legal identifier, display it as a bareword
            ts_coro(key, nil, phrase)
         else
            -- arbitrary string or other type, wrap with braces and repr it
            yield_token("[", c.base)
            -- We want names or hashes for any lvalue table
            ts_coro(key, type(key) == "table" and "tab_name", phrase)
            yield_token("]", c.base)
         end
         EQUALS()
         _tabulate(val, depth + 1, cycle, phrase)
      end
   end
   C_BRACE()
   return nil
end
```

line-buffer goes here


needs to decide when things are 'wide enough' so each yield needs to return
``str, len, done``, where ``str`` is the fragment of string, ``len`` is a number
representing its printable width (don't @ me) and ``done`` is a boolean for if
this is the last bit of the repr of a given thing. Table, userdata, what
have you.


### tabulate(tab, depth, cycle)

This is going to undergo several metamorpheses as we make progress.


For now, we have the ``_tabulate`` function yielding pieces of a table as it
generates them, as well as the printed length (not valid across all Unicode,
but let's shave one yak at a time, shall we?).


Now for the real fun: we need to keep track of indentation levels, and break
'long' maps and arrays up into chunks.


We're yielding a "map" string for k/v type tables and an "array" string for
array-type, and just "end" for the end of either.  What we need is a classic
push-down automaton, and some kind of buffer that's more sophisticated than
just tossing everything into a ``phrase`` table.


#### oneLine(phrase, long)

Returns one line from ``phrase``. ``long`` determines whether we're doing long
lines or short lines, which is determined by ``lineGen``, the caller.

```lua
local function _disp(phrase)
   local displacement = 0
   for _, token in ipairs(phrase) do
      displacement = displacement + token.total_disp
   end
   return displacement
end

local function _spill(phrase, line)
   if line[1].event == "indent" then
      remove(line, 1)
   end
   for i = 1, #line do
      phrase[i] = line[i]
   end
   phrase.yielding = true
   return false
end

local MIN_SPLIT_WIDTH = 20

local function oneLine(phrase, long)
   local line = { make_token(("  "):rep(phrase.level), c.base, "indent") }
   local new_level = phrase.level
   if #phrase == 0 then
      phrase.yielding = true
      return false
   end
   while true do
      local token = remove(phrase, 1)
      -- Don't indent the remainder of a wrapped token
      if token.wrap_part == "rest" then
         assert(remove(line).event == "indent", "Should only encounter rest-of-wrap at start of line")
      end
      insert(line, token)
      if token.event == "array" or token.event == "map" then
         new_level = new_level + 1
      elseif token.event == "end" then
         new_level = new_level - 1
      end
      -- If we are in long mode, remove the trailing space from a comma
      -- Note that in this case we are *certain* that the comma will fit,
      -- since it is only one character and we otherwise reserve one space
      -- for a possible ~
      if token.event == "sep" and long then
         remove(token)
         token.total_disp = token.total_disp - remove(token.disps)
      elseif _disp(line) >= phrase.width then
         remove(line)
         -- Reserve one column for the ~
         local remaining = phrase.width - _disp(line) - 1
         local rest
         -- Only split strings, and only if they're long enough to be worth it
         -- In the extreme event that a non-string token is longer than the
         -- entire available width, split it too to avoid an infinite loop
         if token.is_string and token.total_disp > MIN_SPLIT_WIDTH
            or token.total_disp >= phrase.width then
            token, rest = split_token(token, remaining)
            -- Pad with spaces if we were forced to split a couple chars short
            for i = 1, remaining - token.total_disp do
               insert(token, " ")
               insert(token.disps, 1)
            end
            token.total_disp = remaining
         -- Short strings and other token types just get bumped to the next line
         else
            rest = token
            token = make_token((" "):rep(remaining), c.base)
         end
         token.wrap_part = "first"
         rest.wrap_part = "rest"
         insert(line, token)
         insert(line, make_token("~", c.alert))
         insert(phrase, 1, rest)
      end
      -- If we are in long mode and hit a comma
      if (token.event == "sep" and long)
         -- Or we are at the very end of the stream
         or (#phrase == 0 and not phrase.more)
         -- Or we just needed to chop & wrap a token
         or (token.wrap_part == "first") then
         for i, frag in ipairs(line) do
            line[i] = token_tostring(frag)
         end
         phrase.level = new_level
         return concat(line)
      elseif #phrase == 0 and phrase.more then
         -- spill our fragments back
         return _spill(phrase, line)
      end
   end
end
```
#### lineGen

This function sets up an iterator, which returns one line at a time of the
table.

```lua
local collect, readOnly = assert(core.collect), assert(core.readOnly)
local wrap = assert(coroutine.wrap)

local function _remains(phrase)
   return phrase.width - _disp(phrase)
end

local function lineGen(tab, depth, cycle, disp_width)
   assert(disp_width, "lineGen must have a disp_width")
   local stage = {}              -- stage stack
   local phrase = {
      remains = _remains,
      width = disp_width,
      stage = stage,
      level = 0,                 -- how many levels of recursion are we on
      more = true,               -- are their more frags to come
      yielding = true
   }
   -- make a read-only phrase table for fetching values
   local phrase_ro = readOnly(phrase)
   local iter = wrap(function()
      local success, result = pcall(_tabulate, tab, depth, cycle, phrase_ro)
      if not success then
         local err_lines = collect(lines, tostring(result))
         err_lines[1] = "error in __repr: " .. err_lines[1]
         for _, line in ipairs(err_lines) do
            yield { event = "repr_line",
                    line = line,
                    total_disp = #line }
         end
      end
   end)
   local long = false            -- long or short printing

   -- return an iterator function which yields one line at a time.
   return function()
      ::start::
      while phrase.yielding do
         local token = iter()
         if token == nil then
            phrase.yielding = false
            phrase.more = false
            break
         end
         if token.event then
            local event = token.event
            if event == "repr_line" then
               -- send directly without adding to the phrase
               return token.line
            end
            if event == "array" or event == "map" then
               insert(stage, event)
            elseif event == "end" then
               remove(stage)
            end
         end
         phrase[#phrase + 1] = token

         if _disp(phrase) + (2 * phrase.level) >= disp_width then
            long = true
            phrase.yielding = false
            break
         else
            long = false
         end
      end
      if #phrase > 0 then
            local ln = oneLine(phrase, long)
         if ln then
            return ln
         else
            goto start
            end
      elseif phrase.more == false then
         return nil
      else
         phrase.yielding = true
         goto start
         end
      end
end

function repr.lineGen(tab, disp)
   disp = disp or 80
   return lineGen(tab, nil, nil, disp)
end
```
### repr.lineGenBW(tab, depth, cycle, disp_width)

This generates lines, but with no color.


To keep it from interfering with other uses of the ``repr`` library, we turn
color off and back on with each line.


Global state is annoying!


I mean, module-local global.


But still.

```lua
function repr.lineGenBW(tab, disp_width)
   disp_width = disp_width or 80
   local lg = lineGen(tab, nil, nil, disp_width)
   return function()
      c = C.no_color
      local line = lg()
      if line ~= nil then
         c = C.color
         return line
      end
      c = C.color
      return nil
   end
end
```
```lua
local function tabulate(tab, depth, cycle, disp_width)
   disp_width = disp_width or 80
   local phrase = {}
   for line in lineGen(tab, depth, cycle, disp_width) do
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
      ts_coro(meta, nil, phrase)
   end
   --]]
end
```
### ts_coro

Lots of small, nice things in this one.

```lua
ts_coro = function(value, hint, phrase)
   local str = tostring(value) or ""
   local color

   -- For cases more specific than mere type,
   -- we have hints:
   if hint then
      if hint == "tab_name" then
         str = anti_G[value] or "t:" .. sub(str, -6)
         color = c.table
      elseif hint == "mt" then
         local mt_name = anti_G[value] or "mt:" .. sub(str, -6)
         str = "⟨" .. mt_name .. "⟩"
         color = c.metatable
      elseif hints[hint] then
         color = hints[hint]
      elseif c[hint] then
         color = c[hint]
      else
         error("Unknown hint: " .. hint)
      end
      yield_token(str, color)
      return nil
   end

   local typica = type(value)

   if typica == "table" then
      _tabulate(value, nil, nil, phrase)
      return nil
   elseif typica == "string" then
      -- Special-case handling of string values for escaping
      -- and possible quoting
      yield_token(str, c.string, nil, true)
      return nil
   elseif typica == "function" then
      local f_label = sub(str,11)
      f_label = sub(f_label,1,5) == "built"
                and f_label
                or "f:" .. sub(str, -6)
      str = anti_G[value] or f_label
      color = c.func
   elseif typica == "boolean" then
      color = value and c.truth or c.falsehood
   elseif typica == "number" then
      color = c.number
   elseif typica == "nil" then
      color = c.nilness
   elseif typica == "thread" then
      str = "coro:" .. (anti_G[value] or sub(str, -6))
      color = c.thread
   elseif typica == "userdata" then
      color = c.userdata
      if anti_G[value] then
         str = anti_G[value]
      else
         local name_end = find(str, ":")
         if name_end then
            str = sub(str, 1, name_end - 1)
         end
      end
   elseif typica == "cdata" then
      color = c.cdata
      if anti_G[value] then
         str = anti_G[value]
      end
   end
   yield_token(str, color)
end

repr.ts = tabulate
```
```lua
return repr
```
