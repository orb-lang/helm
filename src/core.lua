







local core = {}












function core.meta(MT)
   if MT and MT.__index then
      -- inherit
      return setmetatable({}, MT)
   elseif MT then
      -- decorate
      MT.__index = MT
      return MT
   else
      -- new metatable
      local _M = {}
      _M.__index = _M
      return _M
   end
end










function core.clone(tab)
   local _M = getmetatable(tab)
   local clone = _M and setmetatable({}, _M) or {}
   for k,v in pairs(tab) do
      clone[k] = v
   end
   return clone
end









local insert = table.insert

local sp_er = "table<core>.splice: "
local _e_1 = sp_er .. "$1 must be a table"
local _e_2 = sp_er .. "$2 must be a number"
local _e_3 = sp_er .. "$3 must be a table"

function core.splice(tab, idx, into)
   assert(type(tab) == "table", _e_1)
   assert(type(idx) == "number", _e_2)
   assert(type(into) == "table", _e_3)
    idx = idx - 1
    local i = 1
    for j = 1, #into do
        insert(tab,i+idx,into[j])
        i = i + 1
    end
    return tab
end






local byte = assert(string.byte)
local find = assert(string.find)
local sub = assert(string.sub)
local format = assert(string.format)











local function continue(c)
   return c >= 128 and c <= 191
end

function core.utf8(c)
   local byte = byte
   local head = byte(c)
   if head < 128 then
      return 1
   elseif head >= 194 and head <= 223 then
      local two = byte(c, 2)
      if continue(two) then
         return 2
      else
         return nil, "utf8: bad second byte"
      end
   elseif head >= 224 and head <= 239 then
      local two, three = byte(c, 2), byte(c, 3)
      if continue(two) and continue(three) then
         return 3
      else
         return nil, "utf8: bad second and/or third byte"
      end
   elseif head >= 240 and head <= 244 then
      local two, three, four = byte(c, 2), byte(c, 3), byte(c, 4)
      if continue(two) and continue(three) and continue(four) then
         return 4
      else
         return nil, "utf8: bad second, third, and/or fourth byte"
      end
   elseif continue(head) then
      return nil, "utf8: continuation byte at head"
   elseif head == 192 or head == 193 then
      return nil, "utf8: 192 or 193 forbidden"
   else -- head > 245
      return nil, "utf8: byte > 245"
   end
end






































local fmt_set = {"L", "q", "s", "t"}

for i, v in ipairs(fmt_set) do
   fmt_set[i] = "%%" .. v
end

--[[
local function next_fmt(str)
   local head, tail
   for _, v in ipairs(fmt_set) do
      head, tail = 2
end]]

function core.format_safe(str, ...)

end









local matches =
  {
    ["^"] = "%^";
    ["$"] = "%$";
    ["("] = "%(";
    [")"] = "%)";
    ["%"] = "%%";
    ["."] = "%.";
    ["["] = "%[";
    ["]"] = "%]";
    ["*"] = "%*";
    ["+"] = "%+";
    ["-"] = "%-";
    ["?"] = "%?";
    ["\0"] = "%z";
  }

function core.litpat(s)
    return (s:gsub(".", matches))
end











function core.cleave(str, pat)
   local at = find(str, pat)
   return sub(str, 1, at - 1), sub(str, at + 1)
end










local function split(str, at)
   return sub(str,1, at), sub(str, at + 1)
end

function core.codepoints(str)
   local utf8 = core.utf8
   local codes = {}
   -- propagate nil
   if not str then return nil end
   -- break on bad type
   assert(type(str) == "string", "codepoints must be given a string")
   while #str > 0 do
      local width, err = utf8(str)
      if width then
         local head, tail = split(str, width)
         codes[#codes + 1] = head
         str = tail
      else
         -- make sure we take a bit off anyway
         str = sub(str, -1)
         -- for debugging
         codes[codes + 1] = { err = err }
      end
   end
   return codes
end



return core
