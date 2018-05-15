


















local a = require "anterm"

local core = require "core"

local WIDE_TABLE = 200 -- should be tty-specific

local C = {}

local thread_shade = a.fg24(240, 50, 100)

local function thread_color(string)
   return a.italic .. thread_shade .. string .. a.clear
end

C.color = {}
C.color.number = a.fg(42)
C.color.string = a.fg(222)
C.color.stresc = a.fg(225)
C.color.table  = a.fg(64)
C.color.func   = a.fg24(210,12,120)
C.color.truth  = a.fg(231)
C.color.falsehood  = a.fg(94)
C.color.nilness    = a.fg(93)
C.color.thread     = thread_color
C.color.field    = a.fg(111)
C.color.userdata = a.fg24(230, 145, 23)
C.color.cdata    = a.fg24(200, 115, 0)
C.color.alert    = a.fg24(250, 0, 40)
C.color.base     = a.fg24(200, 200, 200)








C.color.hints = { field = C.color.field,
                  fn  = C.color.func }
local hints = C.color.hints

local c = C.color
local anti_G = {}

local sort = table.sort










local function tie_break(old, new)
   return #old > #new
end

function C.allNames()
   anti_G[_G] = "_G"
   local function allN(t, aG, pre)
      if pre ~= "" then
         pre = pre .. "."
      end
      sort(t)
      for k, v in pairs(t) do
         T = type(v)
         if (T == "table") then
            key = pre .. k
            if not aG[v] then
               aG[v] = key
               if not (pre == "" and k == "package") then
                  allN(v, aG, key)
               end
            else
               local kv = aG[v]
               if tie_break(kv, key) then
                  -- quadradic lol
                  aG[v] = key
                  allN(v, aG, key)
               end
            end
            local _M = getmetatable(v)
            local _M_id = _M and "⟨" .. pre .. k .. "⟩" or ""
            if _M then
               if not aG[_M] then
                  allN(_M, aG, _M_id)
                  aG[_M] = _M_id
               else
                  local aG_M_id = aG[_M]
                  if tie_break(aG_M_id, _M_id) then
                     allN(_M, aG, _M_id)
                     aG[_M] = _M_id
                  end
               end
            end
         elseif T == "function" or
            T == "thread" or
            T == "userdata" or
            T == "cdata" then
            aG[v] = pre .. k
         end
      end
   end
   allN(_G, anti_G, "")
   return anti_G
end

function C.clearNames()
   anti_G = {}
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
   if depth > 3 then
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
   -- if we have a metatable, get it first
   local mt = ""
   local _M = getmetatable(tab)
   if _M then
      mt = ts(_M, "tab_name") .. c.base(" = ") .. tabulate(_M, depth + 1)
      lines[1] = mt
      i = 2
   else
      i = 1
   end
   local estimated = 0
   for k,v in (is_array and ipairs or pairs)(tab) do
      local s
      if is_array then
         s = ""
      else
         if type(k) == "string" and k:find("^[%a_][%a%d_]*$") then
            s = ts(k) .. c.base(" = ")
         else
            s = c.base("[") .. tabulate(k, 100) .. c.base("] = ")
         end
      end
      s = s .. tabulate(v, depth + 1)
      lines[i] = s
      estimated = estimated + #s
      i = i + 1
   end
   if estimated > WIDE_TABLE then
      return c.base("{\n  ") .. indent
         .. table.concat(lines, ",\n  " .. indent)
         .. "\n" .. indent .. c.base("}")
   else
      return c.base("{ ") .. table.concat(lines, c.base(", ")) .. c.base(" }")
   end
end






local find, sub, gsub, byte = string.find, string.sub,
                              string.gsub, string.byte

local e = function(str)
   return c.stresc(str) .. c.string
end

-- Turn control characters into their byte rep
local function ctrl_pr(str)
   return "\\" .. byte(str)
end

scrub = function (str)
   return str:gsub("\\", e("\\"))
             :gsub("\n", e("\\n"))
             :gsub("\r", e("\\r"))
             :gsub("\t", e("\\t"))
             :gsub("%c", e(ctrl_pr(str)))
end








ts = function (value, hint)
   local str = scrub(tostring(value))
   -- For cases more specific than mere type,
   -- we have hints:
   if hint == "" then
      return str -- or just use tostring()?
   end
   if hint and hint ~= "tab_name" then
      return hints[hint](str)
   elseif hint == "tab_name" then
      if anti_G[value] then
         return c.table(anti_G[value])
      else
         return c.table("t:" .. sub(str, -6))
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
         local func_handle = "f:" .. sub(str, -6)
         str = c.func(func_handle)
      end
   elseif typica == "boolean" then
      str = value and c.truth(str) or c.falsehood(str)
   elseif typica == "string" then
      str = c.string(str)
   elseif typica == "nil" then
      str = c.nilness(str)
   elseif typica == "thread" then
      if anti_G[value] then
         str = c.thread("coro:" .. anti_G[value])
      else
         str = c.thread("coro:" .. sub(str, -6))
      end
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
   end
   return str
end
C.ts = ts



return C
