







local escape_lua_pattern
do
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

local function litpat(s)
    return (s:gsub(".", matches))
  end
end

local function cleave(str, pat)
   local at = string.find(str, pat)
   return string.sub(str, 1, at - 1), string.sub(str, at + 1)
end














local function meta(MT)
   if MT and MT.__index then
      -- inherit
      return setmetatable({}, MT)
   elseif MT then
      -- instantiate
      MT.__index = MT
      return setmetatable({}, MT)
   else
      -- new metatable
      local _M = {}
      _M.__index = _M
      return _M
   end
end





return { litpat = litpat,
         cleave = cleave,
         meta  = meta}
