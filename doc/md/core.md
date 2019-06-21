# Core


``core`` is for tampering with the global namespace and standard libraries.


It will eventually land in ``pylon``.

```lua
local core = {}
```
## Meta Object Protocol

This is where we start to design Cluster.


We shorten a few of the common Lua keywords: ``coro`` rather than ``coroutine``,
and ``getmeta`` and ``setmeta`` over ``getmetatable`` and ``setmetatable``.

### meta

In my code there is a repeated pattern of use that is basic enough that I'm
entering it into the global namespace as simple ``meta``.

```lua
function core.meta(MT, tab)
   tab = tab or {}
   if MT and MT.__index then
      -- inherit
      return setmetatable(tab, MT)
   elseif MT then
      -- decorate
      MT.__index = MT
      return MT
   else
      -- new metatable
      local _M = tab
      _M.__index = _M
      return _M
   end
end
```
### hasmetamethod(tab, mmethod)

The function of this is clear: given a table, return ``true`` if it can receive
a given metamethod.


The question is, how magical to make it. I'm going with "slightly magical" for
now.  You can leave off the "__" in checking for a metamethod.


A successful lookup returns the result, presumable truthy, otherwise ``false``
for a non-table argument and ``nil`` for a failed lookup.

```lua
local sub = assert(string.sub)

function core.hasmetamethod(tab, mmethod)
   assert(type(mmethod) == "string", "metamethod must be a string")
   if sub(mmethod,1,2) == "__" then
      return type(tab) == "table" and tab[mmethod]
   else
      return type(tab) == "table" and tab["__" ..mmethod]
   end
end
```
### endow(Meta)

Performs a thick copy of the metatable.


Because this will include __index and the like, this folds an level of
indirection out of inheritance.


I plan to use this with Nodes when I make a single base class for a complex
Grammar.

```lua
local pairs = assert(pairs)

function core.endow(Meta)
   local MC = {}
   for k, v in pairs(Meta) do
      MC[k] = v
   end
   return MC
end
```

That's just a shallow clone, the subtlety is that if the __index was a
self-table, it now points to ``Meta``, while if Meta was created through
endowment or inheritance it's now out of the picture.

### readOnly(tab)

Makes a table read-only, will throw an error if assigned to.

```lua
local function RO_M__newindex(tab, key, value)
   error("attempt to write value `" .. tostring(value)
         .. "` to read-only table slot `." .. tostring(key) .. "`")
end

function core.readOnly(tab)
   return setmetatable({}, {__index = tab, __newindex = RO_M__newindex})
end
```
## Table extensions

### pack(...)

A 5.2 shim.

```lua
function core.pack(...)
   return { n = select('#', ...), ... }
end
```
### hasfield(field, tab) & hasfield.field(tab)


A nicety which can be used both for predication and assignment.

```lua
local function _hasfield(field, tab)
   if type(tab) == "table" and tab[field] ~= nil then
      return true, tab[field]
   else
      return false
   end
end

local function _hf__index(_, field)
   return function(tab)
      return _hasfield(field, tab)
   end
end

local function _hf__call(_, field, tab)
   return _hasfield(field, tab)
end

core.hasfield = setmetatable({}, { __index = _hf__index,
                                   __call  = _hf__call })
```
### clone(tab, depth)

Performs a shallow clone of table, attaching metatable if available.


Will recurse to ``depth`` if provided.


This will unroll circular references, which may not be what you want.

```lua
local function _clone(tab, depth)
   depth = depth or 1
   assert(depth > 0, "depth must be positive " .. tostring(depth))
   local _M = getmetatable(tab)
   local clone = _M and setmetatable({}, _M) or {}
   for k,v in pairs(tab) do
      if depth > 1 and type(v) == "table" then
        v = _clone(v, depth - 1)
      end
      clone[k] = v
   end
   return clone
end
core.clone = _clone
```
### arrayof(tab)

Clones and returns the array portion of a table.

```lua
function core.arrayof(tab)
   local arr = {}
   for i,v in ipairs(tab) do
      arr[i] = v
   end
   return arr
end
```
### collect(iter, ...)

  Collects and returns up to two tables of values, given an iterator and
arguments to pass to it.

```lua
function core.collect(iter, tab)
   local k_tab, v_tab = {}, {}
   for k, v in iter(tab) do
      k_tab[#k_tab + 1] = k
      v_tab[#v_tab + 1] = v
   end
   return k_tab, v_tab
end
```
### select(tab, key)

Recursively return all ``v`` for ``key`` in all subtables of tab.

#NB: this is not being used and collides with a core library name.```lua
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
```
### reverse(tab)

Reverses (only) the array portion of a table, returning a new table.

```lua
function core.reverse(tab)
   if type(tab) ~= "table" or #tab == 0 then
      return {}
   end
   local bat = {}
   for i,v in ipairs(tab) do
      bat[#tab - i + 1] = v
   end
   return bat
end
```
### keys(tab)

Returns an array of the keys of a table.

```lua
function core.keys(tab)
   assert(type(tab) == "table", "keys must receive a table")
   local keys = {}
   for k, _ in pairs(tab) do
      keys[#keys + 1] = k
   end

   return keys, #keys
end
```
### values(tab)

```lua
function core.values(tab)
   assert(type(tab) == "table", "vals must receive a table")
   local vals = {}
   for _, v in pairs(tab) do
      vals[#vals + 1] = v
   end

   return vals, #vals
end
```
### splice(tab, index, into)

Puts the full contents of ``into`` into ``tab`` at ``index``.  The argument order is
compatible with existing functions and method syntax.


if ``index`` is nil, the contents of ``into`` will be inserted at the end of
``tab``

```lua
local insert = table.insert

local sp_er = "table<core>.splice: "
local _e_1 = sp_er .. "$1 must be a table"
local _e_2 = sp_er .. "$2 must be a number"
local _e_3 = sp_er .. "$3 must be a table"

function core.splice(tab, idx, into)
   assert(type(tab) == "table", _e_1)
   assert(type(idx) == "number" or idx == nil, _e_2)
   if idx == nil then
      idx = #tab + 1
   end
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
### safeget(tab, key)

This will retrieve a value, given a key, without causing errors if the table
has been made strict.

```lua
function core.safeget(tab, key)
   local val = rawget(tab, key)
   if val ~= nil then
      return val
   end
   local _M = getmetatable(tab)
   while _M ~= nil and rawget(_M, "__index") ~= nil do
      local index_t = type(_M.__index)
      if index_t == "table" then
         val = rawget(_M.__index, key)
      elseif index_t == "function" then
         local success
         success, val = pcall(_M.__index, table, key)
         if success then
            return val
         else
            val = nil
         end
      else
         error("somehow, __index is of type " .. index_t)
      end
      if val ~= nil then
         return val
      end
      _M = index_t == "table" and getmetatable(_M.__index) or nil
   end
   return nil
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
### typeformat(str, ...)

Background: I want to start using format in errors and assertions.


It's not as bad to use concatenation in-place for errors, since evaluating
them is a final step.  Assertions run much faster if passed only arguments.


Lua peforms a small number of implicit conversions, mostly at the string
boundary. This is an actual feature since the language has both ``..`` and ``+``,
but it leaves a bit to be desired when it comes to ``string.format``.


``format`` treats any ``%s`` as a request to convert ``tostring``, also treating
``%d`` as a call to ``tonumber``.  The latter I will allow, I'm struggling to find
a circumstance where casting "1" to "1" through ``1`` is dangerous.


What I want is a type-checked ``format``, which I can extend to use a few more
flexible strategies, depending on the context.


Less concerned about hostility and more about explicit coding practices. Also
don't want to undermine hardening elsewhere.


From the wiki, the full set of numeric parameters is
``{A,a,c,d,E,e,f,G,g,i,o,u,X,x}``.  That leaves ``%q`` and ``%s``, the former does
string escaping but of course it is the Lua/C style of escaping.


We add ``%t`` and ``%L`` (for λ), which call ``tostring`` on a table or a function
respectively.  While we're being thorough, ``%b`` for boolean, ``%n`` for ``nil``,
and ``%*`` for the union type.  Why bother with ``nil``, which we can just write?
Type-checking, of course.  We treat ``nil`` as a full type, because in Lua, it
is.


``%t`` will actually accept all remaining compound types: ``userdata``, ``thread``,
and ``cdata``.  For only tables, we can have ``%T``, and also ``%U``, ``%R`` (coRo),
and ``%C``.


Note our ``%L`` is not the C version.  Tempted to have ``%λ`` directly, but
that's a bit weird and it breaks the idea that format sequences are two
bytes long.  While I don't intend to write code that would break in this
case, eh.


``typeformat`` returns the correctly formatted string, or throws an error.

```lua
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
local function cleave(str, pat)
   local at = find(str, pat)
   if at then
      return sub(str, 1, at - 1), sub(str, at + 1)
   else
      return nil
   end
end
core.cleave = cleave
```
```lua
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
### core.slurp(filename)

This takes a (text) file and returns a string containing its whole contents.

```lua
function core.slurp(filename)
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()
  return content
end
```
## Errors and asserts


### Assertfmt

I'll probably just globally replace assert with this over time.


This avoids doing concatenations and conversions on messages that we never
see in normal use.

```lua
local format = string.format

function core.assertfmt(pred, msg, ...)
   if pred then
      return pred
   else
      error(format(msg, ...))
   end
end
```
```lua
return core
```
