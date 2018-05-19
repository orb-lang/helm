# Core


``core`` is for tampering with the global namespace and standard libraries.


It will eventually land in ``pylon``.

```lua
local core = {}
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
   local at = string.find(str, pat)
   return string.sub(str, 1, at - 1), string.sub(str, at + 1)
end
```
## meta

We shorten a few of the common Lua keywords: ``coro`` rather than ``coroutine``,
and ``getmeta`` and ``setmeta`` over ``getmetatable`` and ``setmetatable``.


In my code there is a repeated pattern of use that is basic enough that I'm
entering it into the global namespace as simple ``meta``.

```lua
function core.meta(MT)
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
## clone(tab)

Performs a shallow clone of table, attaching metatable if available.

```lua
function core.clone(tab)
   local _M = getmetatable(tab)
   local clone = _M and setmetatable({}, _M) or {}
   for k,v in pairs(tab) do
      clone[k] = v
   end
   return clone
end
```
## utf8(char)

This takes a string and validates the first character.


Return is either the (valid) length in bytes, or nil and an error string.

```lua

local function continue(c)
   return c >= 128 and c <= 191
end

local byte = assert(string.byte)

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
```
```lua
local sub = assert(string.sub)

local function split(str, at)
   local sub = sub
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

local insert = table.insert
function core.splice(tab, idx, into)
    idx = idx - 1
    local i = 1
    for j = 1, #into do
        insert(tab,i+idx,into[j])
        i = i + 1
    end
    return tab
end

```
```lua
return core
```
