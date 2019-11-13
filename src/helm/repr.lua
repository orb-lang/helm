















local a = require "singletons/anterm"

local core = require "singletons/core"

local C = require "singletons/color"







local repr = {}

local hints = C.color.hints











local anti_G = { _G = "_G" }



















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









function repr.allNames(tab)
   tab = tab or _G
   return addName(package.loaded, addName(tab))
end

function repr.clearNames()
   anti_G = {_G = "_G"}
   return anti_G
end













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


















local hasmetamethod = assert(core.hasmetamethod)
local lines = assert(string.lines)

local function _yieldReprs(tab, phrase, c)
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
   while type(yielder) == 'function' do
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














local Token = require "helm/token"

local function yield_token(...) yield(Token(...)) end

local function name_for(value, c, hint)
   local str = tostring(value) or ""
   local color

   -- For cases more specific than mere type,
   -- we have hints:
   if hint then
      if hint == "mt" then
         str = anti_G[value] or "⟨" .. "mt:" .. sub(str, -6) .. "⟩"
         color = c.metatable
      elseif hints[hint] then
         color = hints[hint]
      elseif c[hint] then
         color = c[hint]
      else
         error("Unknown hint: " .. hint)
      end
      return Token(str, color)
   end

   local typica = type(value)

   if typica == "table" then
      str = anti_G[value] or "t:" .. sub(str, -6)
      color = c.table
   elseif typica == "string" then
      -- Special-case handling of string values for escaping
      -- and possible quoting
      return Token(str, c.string, nil, true)
   elseif typica == "function" then
      color = c.func
      if anti_G[value] then
         str = anti_G[value]
      else
         local f_label = sub(str,11)
         str = sub(f_label,1,5) == "built"
                   and f_label
                   or "f:" .. sub(str, -6)
      end
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
   return Token(str, color)
end








local function yield_name(...) yield(name_for(...)) end

local isarray, table_keys, sort = assert(table.isarray),
                                  assert(table.keys),
                                  assert(table.sort)

local function tabulate(tab, phrase, c, depth, cycle)
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
      _yieldReprs(tab, phrase, c)
      return nil
   end
   -- add non-__repr'ed tables to cycle
   cycle[tab] = true

   -- Okay, we're repring the body of a table of some kind
   -- Check to see if this is an array
   local is_array = isarray(tab)
   -- And print an open brace
   yield_token("{ ", c.base, is_array and "array" or "map")

   -- if we have a metatable, get it first
   local _M = getmetatable(tab)
   if _M then
      if cycle[_M] then
         yield_token("⟨", c.metatable)
      end
      yield_name(_M, c, "mt")
      if cycle[_M] then
         yield_token("⟩ ", c.metatable)
      end
      -- Skip printing the metatable altogether if it's going to end up
      -- represented by its name, since we just printed that.
      if depth < C.depth and not cycle[_M] then
         yield_token(" → ", c.base)
         yield_token("⟨", c.metatable)
         tabulate(_M, phrase, c, depth + 1, cycle)
         yield_token("⟩ ", c.metatable, "sep")
      else
         yield_token(" ", c.base, "sep")
      end
   end

   if is_array then
      for i, val in ipairs(tab) do
         if i ~= 1 then yield_token(", ", c.base, "sep") end
         tabulate(val, phrase, c, depth + 1, cycle)
      end
   else
      local keys = table_keys(tab)
      if #keys <= SORT_LIMIT then
         sort(keys, _keysort)
      end
      for i, key in ipairs(keys) do
         if i ~= 1 then yield_token(", ", c.base, "sep") end
         local val = tab[key]
         if type(key) == "string" and key:find("^[%a_][%a%d_]*$") then
            -- legal identifier, display it as a bareword
            yield_name(key, c)
         else
            -- arbitrary string or other type, wrap with braces and repr it
            yield_token("[", c.base)
            -- We want names or hashes for any lvalue table
            yield_name(key, c)
            yield_token("]", c.base)
         end
         yield_token(" = ", c.base)
         tabulate(val, phrase, c, depth + 1, cycle)
      end
   end
   yield_token(" }", c.base, "end")
   return nil
end










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

local function oneLine(phrase, c, long, force)
   local line = { Token(("  "):rep(phrase.level), c.base, "indent") }
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
      -- for a possible ~. Thus we can skip the check for needing to split
      -- this token, allowing a comma to fit at the very end of a line that
      -- exactly fills the screen.

      -- This is fragile (what if a separator has more than one non-space
      -- character?). What we should really do is still perform the overflow
      -- check, but modify it to use > instead of >= if we are at a separator
      if token.event == "sep" and long then
         token:remove()
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
            token, rest = token:split(remaining)
            -- Pad with spaces if we were forced to split a couple chars short
            for i = 1, remaining - token.total_disp do
               token:insert(" ")
            end
         -- Short strings and other token types just get bumped to the next line
         else
            rest = token
            token = Token((" "):rep(remaining), c.base)
         end
         token.wrap_part = "first"
         rest.wrap_part = "rest"
         insert(line, token)
         insert(line, Token("~", c.alert))
         insert(phrase, 1, rest)
      end
      -- If we are in long mode and hit a comma
      if (token.event == "sep" and long)
         -- Or we are at the very end of the stream,
         -- or have been told to produce a line no matter what
         or (#phrase == 0 and (force or not phrase.more))
         -- Or we just needed to chop & wrap a token
         or (token.wrap_part == "first") then
         for i, frag in ipairs(line) do
            line[i] = frag:toString(c)
         end
         phrase.level = new_level
         return concat(line)
      elseif #phrase == 0 and phrase.more then
         -- spill our fragments back
         return _spill(phrase, line)
      end
   end
end









local collect, readOnly = assert(core.collect), assert(core.readOnly)
local wrap = assert(coroutine.wrap)

local function _remains(phrase)
   return phrase.width - _disp(phrase)
end

local function lineGen(tab, disp_width, c)
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
      local success, result = pcall(tabulate, tab, phrase_ro, c)
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
               -- Clear the buffer, if any, then pass along the __repr() output
               local prev = oneLine(phrase, c, long, true) or ""
               return prev .. token.line
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
            local ln = oneLine(phrase, c, long)
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










function repr.lineGen(tab, disp_width, color)
   color = color or C.color
   disp_width = disp_width or 80
   return lineGen(tab, disp_width, color)
end

function repr.lineGenBW(tab, disp_width)
   disp_width = disp_width or 80
   return lineGen(tab, disp_width, C.no_color)
end









function repr.ts(tab, disp_width)
   local phrase = {}
   for line in repr.lineGen(tab, disp_width) do
      phrase[#phrase + 1] = line
   end
   return concat(phrase, "\n")
end


















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



return repr
