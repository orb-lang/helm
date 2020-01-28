










local core_table, core_string = require "core/table", require "core/string"
local Token = require "helm/repr/token"
local nameFor = require "helm/repr/names" . nameFor
local C = require "singletons/color"

local yield, wrap = assert(coroutine.yield), assert(coroutine.wrap)






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



















local hasmetamethod = require "core/meta" . hasmetamethod
local collect, lines = assert(core_table.collect), assert(core_string.lines)

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
      -- Note that len may be nil, in which case the Token will figure things out for itself
      yield(Token(line, c.no_color, { event = "repr_line", total_disp = len }))
   end
end









local function yield_name(...) yield(nameFor(...)) end

local isarray, table_keys, sort = assert(core_table.isarray),
                                  assert(core_table.keys),
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

