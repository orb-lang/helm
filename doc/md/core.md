# Core


``core`` is for tampering with the global namespace and standard libraries.


It will eventually land in ``femto``.

```lua
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
```
## meta

We shorten a few of the common Lua keywords: ``coro`` rather than ``coroutine``,
and ``getmeta`` and ``setmeta`` over ``getmetatable`` and ``setmetatable``.


In my code there is a repeated pattern of use that is basic enough that I'm
entering it into the global namespace as simple ``meta``.


It is eleven lines long.

```lua
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
```
```lua
return { litpat = litpat,
         cleave = cleave,
         meta  = meta}
```
