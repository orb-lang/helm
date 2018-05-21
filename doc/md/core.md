# Core


``core`` is for tampering with the global namespace and standard libraries.


It will eventually land in ``pylon``.

```lua
local core = {}
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
```
## Table extensions

### clone(tab)

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
### splice(tab, index, into)

Puts the full contents of ``into`` into ``tab`` at ``index``.  The argument order is
compatible with existing functions and method syntax.

```lua
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
```
## String extensions

```lua
local byte = assert(string.byte)
local find = assert(string.find)
local sub = assert(string.sub)
local format = assert(string.format)
```
### utf8(char)

This takes a string and validates the first character.


Return is either the (valid) length in bytes, or nil and an error string.

```lua
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
```
### format_safe(str, ...)

#NB lack the patience to finish this rn. =sqlayer.format= is good enough.
``%d`` as a call to ``tonumber``.  The latter I will allow, I'm struggling to find
a circumstance where casting "1" to "1" through ``1`` is dangerous.


This isn't "safe" in the sense of preventing injections, all it does is check
that its arguments are of a valid type, prohibiting implicit ``tostring``
conversions.  So ``format("select %s from ...", "';drop table users;")`` will
get through, but not
``format("%s", setmeta({}, {__tostring = function() return "'; drop..."}))``.


Less concerned about hostility and more about explicit coding practices. Also
don't want to undermine hardening elsewhere.


From the wiki, the full set of numeric parameters is
``{A,a,c,d,E,e,f,G,g,i,o,u,X,x}``.  That leaves ``%q`` and ``%s``, the former does
string escaping but of course it is the Lua/C style of escaping.


We add ``%t`` and ``%L`` (for λ), which call ``tostring`` on a table or a function
respectively.  ``%t`` will actually accept all remaining compound types:
``userdata``, ``thread``, and ``cdata``.  While we're being thorough, ``%b`` for
boolean.  Perhaps ``%*`` as a wildcard?


Note our ``%L`` is not the C version.


``format_safe`` returns the correctly formatted string, or throws an error.

```lua
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
```
### litpat(s)

``%`` escapes all pattern characters.


The resulting string will literally match ``s`` in ``sub`` or ``gsub``.

```lua
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
```
### cleave(str, patt)

Performs the common operation of returning one run of bytes up to ``patt``
then the rest of the bytes after ``patt``.


Can be used to build iterators, either stateful or coroutine-based.

```lua
function core.cleave(str, pat)
   local at = find(str, pat)
   return sub(str, 1, at - 1), sub(str, at + 1)
end
```
### codepoints(str)

Returns an array of the utf8 codepoints in ``str``, incidentally validating or
rather filtering the contents into utf8 compliance.

```lua

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
```
```lua
return core
```
