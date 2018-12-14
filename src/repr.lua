



















local a = require "anterm"

local core = require "core"

local reflect = require "reflect"

local C = require "color"







local repr = {}

local WIDE_TABLE = 200 -- #todo make this configurable by tty (zone) width.

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









function repr.allNames()
   return addName(package.loaded, addName(_G))
end

function repr.clearNames()
   anti_G = {_G = "_G"}
   return anti_G
end
















local ts

local SORT_LIMIT = 500  -- This won't be necessary #todo remove

assert(coro, "coro must be in the namespace")

local yield, wrap = coro.yield, coro.wrap

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

local function _tabulate(tab, depth, cycle)
   cycle = cycle or {}
   depth = depth or 0
   if type(tab) ~= "table" then
      yield(ts(tab)); return nil
   end
   if depth > C.depth or cycle[tab] then
      yield(ts(tab, "tab_name")); return nil
   end
   cycle[tab] = true
   local indent = ("  "):rep(depth)
   -- Check to see if this is an array
   local is_array = true
   local i = 1
   for k,v in pairs(tab) do
      if not (k == i) then
         is_array = false
      end
      i = i + 1
   end
   local first = true
   local lines = {}
   -- if we have a metatable, get it first
   local mt = ""
   local _M = getmetatable(tab)
   if _M then
      mt = ts(tab, "mt") .. c.base(" = ")
           .. _tabulate(_M, depth + 1, cycle)
      lines[1] = mt
      i = 2
   else
      i = 1
   end
   local estimated = 0
   local keys
   if not is_array then
      keys = table.keys(tab)
      if #keys <= SORT_LIMIT then
         table.sort(keys, _keysort)
      else
         -- bail
         yield "{ !!! }"; return nil
      end
   else
      if #tab > SORT_LIMIT then
         yield "{ #!!! }"; return nil
      end
      keys = tab
   end
   for j, k in ipairs(keys) do
      -- this looks dumb but
      -- the result is that k is key
      -- and v is value for either type of table
      local v
      if is_array then
         v = k
         k = j
      else
         v = tab[k]
      end
      local s
      if is_array then
         s = ""
      else
         if type(k) == "string" and k:find("^[%a_][%a%d_]*$") then
            s = ts(k) .. c.base(" = ")
         else
            s = c.base("[")
                .. _tabulate(k, 100, cycle) .. c.base("] = ")
         end
      end
      s = s .. _tabulate(v, depth + 1, cycle)
      lines[i] = s
      estimated = estimated + #s
      i = i + 1
   end
   if estimated > WIDE_TABLE then
   --[[
      yield (c.base("{ ") .. indent
         .. table.concat(lines, ",\n  " .. indent)
         ..  c.base(" }")); return nil
   --]]
      yield(c.base("{ ") .. indent .. lines[1] .. ",\n")
      local i = 2
      while true do
         local line = lines[i]
         i = i + 1
         if line ~= nil then
            yield(indent .. line .. ",\n")
         else
            yield(indent ..  c.base(" }"))
            break
         end
      end
   else
      yield (c.base("{ ") .. table.concat(lines, c.base(", ")) .. c.base(" }"))
   end
   return nil
end

local function tabulate(...)
   local phrase = {}
   local iter = wrap(_tabulate)
   while true do
      local line = iter(...)
      if line == nil then break end
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
      local mt_str = ts(meta)
      return str .. " = " .. mt_str
   else
      return str
   end
end







ts = function (value, hint)
   local strval = tostring(value) or ""
   local str = scrub(strval)
   -- For cases more specific than mere type,
   -- we have hints:
   if hint then
      if hint == "tab_name" then
         local tab_name = anti_G[value] or "t:" .. sub(str, -6)
         return c.table(tab_name)
      elseif hint == "mt" then
         local mt_name = anti_G[value] or "mt:" .. sub(str, -6)
         return c.metatable("⟨" .. mt_name .. "⟩")
      elseif hints[hint] then
         return hints[hint](str)
      elseif c[hint] then
         return c[hint](str)
      end
   end

   local typica = type(value)

   if typica == "table" then
      -- check for a __repr metamethod
      local _M = getmetatable(value)
      if _M and _M.__repr and not (hint == "raw") then
         str = _M.__repr(value, c)

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
      str = c.func(func_name)
   elseif typica == "boolean" then
      str = value and c.truth(str) or c.falsehood(str)
   elseif typica == "string" then
      if value == "" then
         str = c.string('""')
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
      str = c.thread(coro_name)
   elseif typica == "userdata" then
      if anti_G[value] then
         str = c.userdata(anti_G[value])
      else
         local name = find(str, ":")
         if name then
            str = c.userdata(sub(str, 1, name - 1))
         else
            str = c.userdata(str)
         end
      end
   elseif typica == "cdata" then
      if anti_G[value] then
         str = c.cdata(anti_G[value])
      else
         str = c.cdata(str)
      end
      str = c_data(value, str)
   end
   return str
end

repr.ts = ts



function repr.ts_bw(value)
   c = C.no_color
   local to_string = ts(value)
   c = C.color
   return to_string
end



return repr
