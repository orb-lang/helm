





local a = require "anterm"

local C = {}
C.color = {}
C.color.number = a.fg(42)
C.color.string = a.fg(222)
C.color.table  = a.fg(64)
C.color.func   = a.fg24(210,12,120)
C.color.truth  = a.fg(231)
C.color.falsehood  = a.fg(94)
C.color.nilness   = a.fg(93)
C.color.field  = a.fg(111)
C.color.userdata = a.fg24(230, 145, 23)
C.color.alert = a.fg24(250, 0, 40)

local c = C.color










local hints = { field = C.color.field,
                  fn  = C.color.func }

local anti_G = {}
anti_G[_G] = "_G"

local scrub -- this takes escapes out
function C.allNames()
   local function allN(t, aG, pre)
      if pre ~= "" then
         pre = pre .. "."
      end
      for k, v in pairs(t) do
         T = type(v)
         if (T == "table") then
            if not aG[v] then
               aG[v] = pre .. k
               allN(v, aG, k)
            end
         elseif T == "function" then
            aG[v] = pre .. k
         end
      end
   end
   allN(_G, anti_G, "")
   return anti_G
end





local ts
local function tabulate(tab, depth)
   if type(tab) ~= "table" then
      return ts(tab)
   end
   if type(depth) == "nil" then
      depth = 0
   end
   if depth > 2 then
      return ts(tab, "tab_name")
   end
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
   i = 1
   local estimated = 0
   for k,v in (is_array and ipairs or pairs)(tab) do
      local s
      if is_array then
         s = ""
      else
         if type(k) == "string" and k:find("^[%a_][%a%d_]*$") then
            s = ts(k) .. c.table(" = ")
         else
            s = c.table("[") .. tabulate(k, 100) .. c.table("] = ")
         end
      end
      s = s .. tabulate(v, depth + 1)
      lines[i] = s
      estimated = estimated + #s
      i = i + 1
   end
   if estimated > 200 then
      return "{\n  " .. indent
         .. table.concat(lines, ",\n  " .. indent)
         .. "\n" .. indent .. "}"
   else
      return c.table("{ ") .. table.concat(lines, ", ") .. c.table(" }")
   end
end



scrub = function (str)
   return string.gsub(str, "\27", "\\27")
end

local find, sub = string.find, string.sub
ts = function (value, hint)
   local str = scrub(tostring(value))
   if hint == "" then
      return str -- or just use tostring()?
   end
   if hint and hint ~= "tab_name" then
      return hints[hint](str)
   elseif hint == "tab_name" then
      if anti_G[value] then
         return c.table(anti_G[value])
      else
         return c.table(str)
      end
   end

   local typica = type(value)
   if typica == "number" then
      str = c.number(str)
   elseif typica == "table" then
      str = tabulate(value)
   elseif typica == "function" then
      if anti_G[value] then
         -- we have a global name for this function
         str = c.func(anti_G[value])
      else
         local func_handle = "f:" .. string.sub(str, -6)
         str = c.func(func_handle)
      end
   elseif typica == "boolean" then
      str = value and c.truth(str) or c.falsehood(str)
   elseif typica == "string" then
      str = c.string(str)
   elseif typica == "nil" then
      str = c.nilness(str)
   elseif typica == "userdata" then
      local name = find(str, ":")
      if name then
         str = c.userdata(sub(str, 1, name - 1))
      else
         str = c.userdata(str)
      end
   end
   return str
end
C.ts = ts



return C
