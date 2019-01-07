















local a = require "anterm"

local core = require "core"

local reflect = require "reflect"

local C = require "color"







local repr = {}

local hints = C.color.hints

local c = C.color










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
         local key = pre .. (type(k) == "string" and k or "<" .. type(k) .. ">")
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











local ts, ts_coro

local SORT_LIMIT = 500  -- This won't be necessary #todo remove

local coro = coro or coroutine

local yield, wrap = coro.yield, coro.wrap

local collect = assert(table.collect)

local concat = table.concat

local function _keysort(a, b)
   if type(a) == "number" and type(b) == "string" then
      return true
   elseif type(a) == "string" and type(b) == "number" then
      return false
   elseif (type(a) == "string" and type(b) == "string")
      or (type(a) == "number" and type(b) == "number") then
      return a < b
   else
      return false
   end
end













local O_BRACE = c.base "{"
local C_BRACE = c.base "}"

local function _tabulate(tab, depth, cycle)
   cycle = cycle or {}
   depth = depth or 0
   if type(tab) ~= "table" then
      ts_coro(tab)
      return nil
   end
   if depth > C.depth or cycle[tab] then
      yield(ts(tab, "tab_name"))
      return nil
   end

   cycle[tab] = true
   -- Check to see if this is an array
   local is_array = true
   local i = 1
   for k,_ in pairs(tab) do
      is_array = is_array and (k == i)
      i = i + 1
   end
   -- if we have a metatable, get it first
   local mt = ""
   local _M = getmetatable(tab)
   if _M then
      -- fix metatable stuff

      local mt_rep, mt_len = ts(tab, "mt")
      yield(mt_rep, mt_len)
      yield(c.base(" = "), 3)
      _tabulate(_M, depth + 1, cycle)
   end
   local estimated = 0
   local keys
   if not is_array then
      keys = table.keys(tab)
      if #keys <= SORT_LIMIT then
         table.sort(keys, _keysort)
      else
         -- bail
         yield("{ !!! }", 7, "end"); return nil
      end
   else
      if #tab > SORT_LIMIT then
         yield("{ #!!! }", 8, "end"); return nil
      end
      keys = tab
   end
   yield(O_BRACE, 1, (is_array and "array" or "map"))
   for j, key in ipairs(keys) do
      if is_array then
         _tabulate(key, depth + 1, cycle)
      else
         val = tab[key]
         if type(key) == "string" and key:find("^[%a_][%a%d_]*$") then
            ts_coro(key)
            yield(c.base(" = "), 3)
         else
            yield(c.base("["), 1)
               -- we want names or hashes for any lvalue table,
               -- 100 triggers this
            _tabulate(key, 100, cycle)
            yield(c.base("] = "), 4)
         end
         _tabulate(val, depth + 1, cycle)
      end
   end
   yield(C_BRACE, 1, "end")
   return nil
end


































local function oneLine(phrase, long)
   return table.concat(phrase)
end








local COMMA, COM_LEN = c.base ", ", 2

local function lineGen(tab, depth, cycle)
   local phrase = {}
   local iter = wrap(_tabulate)
   local stage = ""
   local map_counter = 0         -- this counts where commas go
   local skip_comma = false      -- no comma at end of array/map
   local stack, old_stack = 0, 0 -- level of recursion
   local disp = 0                -- column displacement
   local yielding = true
   -- return an iterator function that currently yields the entire
   -- line but will eventually yield one line at a time.
   return function()
      while yielding do
         local line, len, event = iter(tab, depth, cycle)
         if line == nil then
            break
         end
         phrase[#phrase + 1] = line
         disp = disp + len
         if event then
            if event == "map" then
               map_counter = 0
            end
            if event == "array" or event == "map" then
               stack = stack + 1
               skip_comma = true
            elseif event == "end" then
               stack = stack - 1
               assert(stack >= 0, "(tabulate) stack underflow")
            end
            -- don't think I need the conditional below
            if stage ~= event then
               skip_comma = true
            end
            if (stage == "array" or stage == "map")
               and event == "end" then
               skip_comma = true
            end
            -- this is seriously esoteric but fixes cases like {{},{}}
            if old_stack < stack and phrase[#phrase -1] == C_BRACE then
               table.insert(phrase, #phrase, COMMA)
               disp = disp + COM_LEN
            end
            stage = event
         end
         -- special-case for non-string values, which
         -- yield an extra piece
         if line == c.base("] = ") then
            map_counter = map_counter - 1
         end
         -- insert commas
         if stage =="map"  then
            if map_counter == 3 then
               phrase[#phrase + 1] = COMMA
               disp = disp + COM_LEN
               map_counter = 1
            else
               map_counter = map_counter + 1
            end
         elseif stage == "array" and not skip_comma then
            phrase[#phrase + 1] = COMMA
            disp = disp + COM_LEN
            map_counter = map_counter + 1
         end
         skip_comma = false
         -- if we had a comma before ending a map/array (this is normal)
         -- then remove it
         -- #nb there may be a way to do this using skip_comma but this
         -- works, dammit.
         if stage == "end" and phrase[#phrase - 1] == COMMA then
            table.remove(phrase, #phrase - 1)
            disp = disp - COM_LEN
         end
         old_stack = stack
      end
      if yielding then
         yielding = false
         return oneLine(phrase)
      else
         return nil
      end
   end
end

local function tabulate(...)
   local phrase = {}
   for line in lineGen(...) do
      phrase[#phrase + 1] = line
   end
   return table.concat(phrase)
end









local find, sub, gsub, byte = string.find, string.sub,
                              string.gsub, string.byte

local e = function(str)
   return c.stresc .. str .. c.string
end

-- Turn control characters into their byte rep,
-- preserving escapes
local function ctrl_pr(str)
   if byte(str) ~= 27 then
      return e("\\" .. byte(str))
   else
      return str
   end
end

local function scrub (str)
   return str:gsub("\27", e "\\x1b")
             :gsub('"',  e '\\"')
             :gsub("'",  e "\\'")
             :gsub("\a", e "\\a")
             :gsub("\b", e "\\b")
             :gsub("\f", e "\\f")
             :gsub("\n", e "\\n")
             :gsub("\r", e "\\r")
             :gsub("\t", e "\\t")
             :gsub("\v", e "\\v")
             :gsub("%c", ctrl_pr)
end



local function c_data(value, str)
   local meta = reflect.getmetatable(value)
   if meta then
      local mt_str, meta_len = ts(meta)
      meta_len = meta_len or #mt_str
      return str .. " = " .. mt_str, meta_len
   else
      return str, #str
   end
end







ts_coro = function (value, hint)
   local strval = tostring(value) or ""
   local len = #strval
   local str = scrub(strval)

   -- For cases more specific than mere type,
   -- we have hints:
   if hint then
      if hint == "tab_name" then
         local tab_name = anti_G[value] or "t:" .. sub(str, -6)
         len = #tab_name
         yield(c.table(tab_name), len)
      elseif hint == "mt" then
         local mt_name = anti_G[value] or "mt:" .. sub(str, -6)
         len = #mt_name + 2
         yield(c.metatable("⟨" .. mt_name .. "⟩"), len); return nil
      elseif hints[hint] then
         yield(hints[hint](str), len)
      elseif c[hint] then
         yield(c[hint](str), len)
      end
   end

   local typica = type(value)

   if typica == "table" then
      -- check for a __repr metamethod
      local _M = getmetatable(value)
      if _M and _M.__repr and not (hint == "raw") then
         local repr_len
         str, repr_len  = _M.__repr(value, c)
         len = repr_len or len
         assert(type(str) == "string")
      else
         str = tabulate(value)
      end
   elseif typica == "function" then
      local f_label = sub(str,11)
      f_label = sub(f_label,1,5) == "built"
                and f_label
                or "f:" .. sub(str, -6)
      local func_name = anti_G[value] or f_label
      len = #func_name
      str = c.func(func_name)
   elseif typica == "boolean" then
      str = value and c.truth(str) or c.falsehood(str)
   elseif typica == "string" then
      if value == "" then
         str = c.string('""')
         len = 2
      else
         str = c.string(str)
      end
   elseif typica == "number" then
      str = c.number(str)
   elseif typica == "nil" then
      str = c.nilness(str)
   elseif typica == "thread" then
      local coro_name = anti_G[value] and "coro:" .. anti_G[value]
                                      or  "coro:" .. sub(str, -6)
      len = #coro_name
      str = c.thread(coro_name)
   elseif typica == "userdata" then
      if anti_G[value] then
         str = c.userdata(anti_G[value])
         len = #anti_G[value]
      else
         local name = find(str, ":")
         if name then
            name = sub(str, 1, name - 1)
            len = #name
            str = c.userdata(name)
         else
            str = c.userdata(str)
         end
      end
   elseif typica == "cdata" then
      if anti_G[value] then
         str = c.cdata(anti_G[value])
         len = anti_G[value]
      else
         str = c.cdata(str)
      end
      str, len = c_data(value, str)
   end
   yield(str, len)
end

ts = function(...)
      local rep, len, done = wrap(ts_coro)(...)
      return rep, len, done
end

repr.ts = ts



function repr.ts_bw(value)
   c = C.no_color
   local to_string = ts(value)
   c = C.color
   return to_string
end



return repr
