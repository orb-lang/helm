







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















local sub = assert(string.sub)

function core.hasmetamethod(tab, mmethod)
   assert(type(mmethod) == "string", "metamethod must be a string")
   if sub(mmethod,1,2) == "__" then
      return type(tab) == "table" and tab[mmethod]
   else
      return type(tab) == "table" and tab["__" ..mmethod]
   end
end













local pairs = assert(pairs)

function core.endow(Meta)
   local MC = {}
   for k, v in pairs(Meta) do
      MC[k] = v
   end
   return MC
end
















local function _hasfield(field, tab)
   if type(tab) == "table" and tab[field] ~= nil then
      return true, tab[field]
   else
      return false
   end
end

function _hf__index(_, field)
   return function(tab)
      return _hasfield(field, tab)
   end
end

function _hf__call(_, field, tab)
   return _hasfield(field, tab)
end

core.hasfield = setmetatable({}, { __index = _hf__index,
                                   __call  = _hf__call })







function core.clone(tab)
   local _M = getmetatable(tab)
   local clone = _M and setmetatable({}, _M) or {}
   for k,v in pairs(tab) do
      clone[k] = v
   end
   return clone
end








function core.arrayof(tab)
   local arr = {}
   for i,v in ipairs(tab) do
      arr[i] = v
   end
   return arr
end









function core.collect(iter, tab)
   local k_tab, v_tab = {}, {}
   for k, v in iter(tab) do
      k_tab[#k_tab + 1] = k
      v_tab[#v_tab + 1] = v
   end
   return k_tab, v_tab
end








local function _select(collection, tab, key, cycle)
   cycle = cycle or {}
   for k,v in pairs(tab) do
      if key == k then
         collection[#collection + 1] = v
      end
      if type(v) == "table" and not cycle[v] then
         cycle[v] = true
         collection = _select(collection, v, key, cycle)
      end
   end
   return collection
end

function core.select(tab, key)
   return _select({}, tab, key)
end








function core.reverse(tab)
   local bat = {}
   for i,v in ipairs(tab) do
      bat[#tab - i + 1] = v
   end
   assert(bat[1])
   assert(bat[#tab])
   return bat
end








function core.keys(tab)
   assert(type(tab) == "table", "keys must receive a table")
   local keys = {}
   for k, _ in pairs(tab) do
      keys[#keys + 1] = k
   end

   return keys, #keys
end






function core.values(tab)
   assert(type(tab) == "table", "vals must receive a table")
   local vals = {}
   for _, v in pairs(tab) do
      vals[#vals + 1] = v
   end

   return vals, #vals
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














































local fmt_set = {"*", "C", "L", "R", "T", "U", "b", "n", "q", "s", "t" }

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











local function cleave(str, pat)
   local at = find(str, pat)
   if at then
      return sub(str, 1, at - 1), sub(str, at + 1)
   else
      return nil
   end
end
core.cleave = cleave



local yield, wrap = assert(coroutine.yield), assert(coroutine.wrap)

local function _lines(str)
   if str == "" or not str then return nil end
   local line, rem = cleave(str, "\n")
   if line then
      yield(line)
   else
      yield(str)
   end
   _lines(rem)
end

local function lines(str)
  return coroutine.wrap(function() return _lines(str) end)
end

core.lines = lines










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














local format = string.format

function core.assertfmt(pred, msg, ...)
   if pred then
      return pred
   else
      error(format(msg, ...))
   end
end



return core
