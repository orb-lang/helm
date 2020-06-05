# tabulator

This is fundamentally [Tim Caswell's](https://github.com/creationix) code\.

I've dressed it up a bit\. Okay, a lot\.

\#todo

## Dependencies

```lua
local core_table, core_string = require "core/table", require "core/string"
local Token = require "helm/repr/token"
local nameFor = require "helm/repr/names" . nameFor
local C = require "singletons/color"

local yield, wrap = assert(coroutine.yield), assert(coroutine.wrap)
```

### Sorting

```lua

local SORT_LIMIT = 500  -- This won't be necessary #todo remove

local function _keysort(a, b)
   if (type(a) == "string" and type(b) == "string")
      or (type(a) == "number" and type(b) == "number") then
      return a < b
   elseif type(a) == "number" and type(b) == "string" then
      return false
   elseif type(a) == "string" and type(b) == "number" then
      return true
   else
      return false
   end
end

```

### \_yieldReprs\(tab, window, c\)

I want to deliver `__repr`s from inside the funky coroutine brew,
because, well, because\. `ts` is meant to be general\.

I also want a lot of flexibility in how reprs are written, so we need to
handle several cases\.

We're going to start with returning a string, and returning an iterator\.

I might get around to returning tables with tokens in them and other intel,
I might not; I do have plans that are broader than merely writing an
incredibly intricate repl\.

```lua

local hasmetamethod = assert(require "core/meta" . hasmetamethod)
local collect, lines = assert(core_table.collect), assert(core_string.lines)
local assertfmt = assert(require "core/fn" . assertfmt)

local function _yieldReprs(tab, window, c)
   local _repr = hasmetamethod("repr", tab)
   assert(c, "must have a value for c")
   assert(_repr, "failed to retrieve repr metamethod")
   local repr = _repr(tab, window, c)
   -- __repr may choose to use yield() directly rather than returning a value
   if repr == nil then return end
   if type(repr) == "string" then
      repr = lines(repr)
   end
   assertfmt(type(repr) == "function",
      "Unexpected return type from __repr: \
      Expected string, iterator-of-string, or iterator-of-Token, got %s",
      type(repr))
   for line_or_token, len in repr do
      local token
      if type(line_or_token) == "string" then
         -- Note that len may be nil, in which case the Token will figure things out for itself
         token = Token(line_or_token, c.no_color, { event = "repr_line", total_disp = len })
      else
         token = line_or_token
      end
      yield(token)
   end
end

```

### tabulate\(tab, window, c\)

Returns an iterator that produces Tokens representing pieces of a table,
recursively, one at a time\. Implemented internally as a coroutine\.

```lua
local function yield_name(...) yield(nameFor(...)) end

local isarray, table_keys, sort = assert(core_table.isarray),
                                  assert(core_table.keys),
                                  assert(table.sort)

local function _tabulate(tab, window, c)
   if type(tab) ~= "table"
      or window.depth > C.depth
      or window.cycle[tab] then
      yield_name(tab, c)
      return nil
   end
   -- Check for an __repr metamethod. If present, it replaces the rest of the
   -- tabulation process for this table
   if hasmetamethod("repr", tab) and (not rawget(tab, "__repr")) then
      window.depth = window.depth + 1
      _yieldReprs(tab, window, c)
      window.depth = window.depth - 1
      return nil
   end
   -- add non-__repr'ed tables to cycle
   window.cycle[tab] = true

   -- Okay, we're repring the body of a table of some kind
   -- Check to see if this is an array
   local is_array = isarray(tab)
   -- And print an open brace, noting increased depth
   yield(Token("{ ", c.base, { event = is_array and "array" or "map" }))
   window.depth = window.depth + 1

   -- if we have a metatable, get it first
   local _M = getmetatable(tab)
   if _M then
      local mt_name_token = nameFor(_M, c, "metatable")
      mt_name_token.event = "metatable"
      if window.cycle[_M] then
         mt_name_token:insert(1, "⟨")
         mt_name_token:insert("⟩")
         mt_name_token:insert(" ")
      end
      yield(mt_name_token)
      -- Skip printing the metatable altogether if it's going to end up
      -- represented by its name, since we just printed that.
      if window.depth < C.depth and not window.cycle[_M] then
         yield(Token(" → ", c.base, { event = "sep" }))
         yield(Token("⟨", c.metatable, { event = "metatable" }))
         _tabulate(_M, window, c)
         yield(Token("⟩ ", c.metatable, { event = "sep"}))
      else
         yield(Token(" ", c.no_color, { event = "sep" }))
      end
   end

   if is_array then
      for i, val in ipairs(tab) do
         if i ~= 1 then yield(Token(", ", c.base, { event = "sep" })) end
         _tabulate(val, window, c)
      end
   else
      local keys = table_keys(tab)
      if #keys <= SORT_LIMIT then
         sort(keys, _keysort)
      end
      for i, key in ipairs(keys) do
         if i ~= 1 then yield(Token(", ", c.base, { event = "sep" })) end
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
         _tabulate(val, window, c)
      end
   end
   yield(Token(" }", c.base, { event = "end" }))
   window.depth = window.depth - 1
   return nil
end

local function tabulate(tab, window, c)
   return wrap(function()
      window.depth = 0
      window.cycle = {}
      local err_lines
      local success, result = xpcall(
         function() return _tabulate(tab, window, c) end,
         function(err)
            err_lines = collect(lines, debug.traceback(tostring(err)))
            err_lines[1] = "error in __repr: " .. err_lines[1]
         end)
      if err_lines then
         for _, line in ipairs(err_lines) do
            yield(Token(line, c.alert, { event = "repr_line" }))
         end
      end
   end)
end

return tabulate

```