



















local a = require "anterm"

local core = require "core"

local reflect = require "reflect"

local WIDE_TABLE = 200 -- should be tty-specific

local C = {}

local thread_shade = a.fg24(240, 50, 100)

local function thread_color(str)
   return a.italic .. thread_shade .. str .. a.clear
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
C.color.coro       = thread_color
C.color.field      = a.fg(111)
C.color.userdata   = a.fg24(230, 145, 23)
C.color.cdata      = a.fg24(200, 115, 0)
C.color.metatable  = a.fg24(242, 0, 234)
C.color.meta       = C.color.metatable

C.color["function"] = C.color.func
C.color["true"]     = C.color.truth
C.color["false"]    = C.color.falsehood
C.color["nil"]      = C.color.nilness

C.color.operator = a.fg24(220, 40, 150)
C.color.keyword = a.fg24(100, 210, 100)
C.color.comment = a.fg24(128,128,128)


C.color.alert      = a.fg24(250, 0, 40)
C.color.base       = a.fg24(200, 200, 200)
C.color.search_hl = a.fg24(30, 230, 100)
C.color.error = a.bg24(50,0,0)


C.depth = 4 -- table print depth









local no_color = {}
-- if field accessed, pass through
local function _no_c_index(nc, _)
   return nc
end

local function _no_c_call(_, str)
   return str or ""
end

local function _no_c_concat(head, tail)
   head = type(head) == "string" and head or ""
   tail = type(tail) == "string" and tail or ""
   return head .. tail
end

C.no_color = setmetatable({}, { __index  = _no_c_index,
                                __call   = _no_c_call,
                                __concat = _no_c_concat, })











C.color.hints = { field = C.color.field,
                  fn    = C.color.func,
                  mt    = C.color.mt }

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

function C.allNames()
   return addName(package.loaded, addName(_G))
end

function C.clearNames()
   anti_G = {_G = "_G"}
   return anti_G
end












local ts

local function tabulate(tab, depth, cycle)
   cycle = cycle or {}
   if type(tab) ~= "table" then
      return ts(tab)
   end
   if type(depth) == "nil" then
      depth = 0
   end
   if depth > C.depth or cycle[tab] then
      return ts(tab, "tab_name")
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
      mt = ts(tab, "mt") .. c.base(" = ") .. tabulate(_M, depth + 1, cycle)
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
            s = c.base("[") .. tabulate(k, 100, cycle) .. c.base("] = ")
         end
      end
      s = s .. tabulate(v, depth + 1, cycle)
      lines[i] = s
      estimated = estimated + #s
      i = i + 1
   end
   if estimated > WIDE_TABLE then
      return c.base("{\n  ") .. indent
         .. table.concat(lines, ",\n  " .. indent)
         ..  c.base("}")
   else
      return c.base("{ ") .. table.concat(lines, c.base(", ")) .. c.base(" }")
   end
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
   local str = scrub(tostring(value))
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

C.ts = ts



function C.ts_bw(value)
   c = C.no_color
   local to_string = ts(value)
   c = C.color
   return to_string
end



return C
