# SQLayer

This will be in pylon eventually.


Enhances the existing SQLite bindings, which in turn will be turned into a
statically-linked part of ``pylon``.


SQLite being a core competency, we want to make this really nice; see
[[stretch goals][#stretch-goals]] for details.

```lua
local sql = require "sqlite"
local pcall = assert (pcall)
local gsub = assert(string.gsub)
local format = assert(string.format)
assert(ffi)
assert(ffi.reflect)
```
### Monkey Patches

It's time to start decorating the ``conn`` and ``stmt`` metatables.


First we must summon them from the ether.

```lua
-- get a conn object via in-memory DB
local conn = sql.open ":memory:"
local conn_mt = ffi.reflect.getmetatable(conn)
local stmt = conn:prepare "CREATE TABLE IF NOT EXISTS test(a,b);"
local stmt_mt = ffi.reflect.getmetatable(stmt)
conn:close() -- polite
conn, stmt = nil, nil
```
## sql.san(str)

Sanitizes a string for SQL(ite) quoting.

```lua
local function san(str)
   return gsub(str, "'", "''")
end

sql.san = san
```
## sql.format(str)

The SQLite bindings I'm using support only an impoverished subset of the
SQLite binds.  In the meantime we're going to use format strings, which at
least typecheck parameters.


**Update** I've added ``bindkv`` which helps.


This ``format`` command sanitizes string inputs, and also replaces any ``%s``
with ``'%s'`` without making any ``''%s''``, or more accurately trimming them
if it creates them.


So ``sql.format("it's %s!", "it's")`` and ``sql.format("it's '%s'!", "it's")``
both yield ``"it's 'it''s"``.  I figure any apostrophes in the format string
belong there.


Failure to format returns ``false, err``.

```lua
function sql.format(str, ...)
   local argv = {...}
   str = gsub(str, "%%s", "'%%s'"):gsub("''%%s''", "'%%s'")
   for i, v in ipairs(argv) do
      if type(v) == "string" then
         argv[i] = san(v)
      elseif type(v) == "cdata" then
         -- assume this is a number of some kind
         argv[i] = tonumber(v)
      else
         argv[i] = v
      end
   end
   local success, ret = pcall(format, str, unpack(argv))
   if success then
      return ret
   else
      return success, ret
   end
end
```
## sql.pexec(conn, stmt)

Executes the statement on conn in protected mode.


Unwraps and returns success, or ``false`` and error.

```lua
function sql.pexec(conn, stmt, col_str)
   -- conn:exec(stmt)
   col_str = col_str or "hik"
   local success, result, nrow = pcall(conn.exec, conn, stmt, col_str)
   if success then
      return result, nrow
   else
      return false, result
   end
end
```
## sql.lastid(conn)

This could be improved by natively handling uint64_t ``cdata``.


Y'know, if we ever keep more than 53 bits width of rows in uhhhhh SQLite.

```lua
function sql.lastRowId(conn)
   local result = conn:rowexec "SELECT CAST(last_insert_rowid() AS REAL)"
   return result
end
```
#### conn.pragma.etc(bool)

A convenience wrapper over the SQL pragma commands.


We can use the same interface for setting Lua-specific values, the one I need
is ``conn.pragma.nulls_are_nil(false)``.


This is a subtle bit of function composition with a nice result.


I might be able to use this technique in ``check`` to favor ``.`` over ``:``.

```lua
local pragma_pre = "PRAGMA "
local c = require "color"

-- Builds and returns a pragma string
local function __pragma(prag, value)
   local val
   if value == nil then
      return pragma_pre .. prag .. ";"
   end
   if type(value) == "boolean" then
      val = value and " = 1" or " = 0"
   elseif type(value) == "string" then
      val = "('" .. san(value) .. "')"
   elseif type(value) == "number" then
      val = " = " .. tostring(value)
   else
      error(false, "value of type " .. type(value) .. ", " .. c.ts(value))
   end
   return pragma_pre .. prag .. val .. ";"
end

-- Sets a pragma and checks its new value
local function _prag_set(conn, prag)
   return function(value)
      local prag_str = __pragma(prag, value)
      conn:exec(prag_str)
      -- check for a boolean
      -- #todo make sure this gives sane results for a method-call pragma
      local answer = conn:exec(pragma_pre .. prag .. ";")
      if answer[1] and answer[1][1] then
         if answer[1][1] == 1 then
            return true
         elseif answer[1][1] == 0 then
            return false
         else
            return nil
         end
      end
   end
end
```

This is the fun part: we swap the old metatable for a function which closes
over our ``conn``, passing it along to the pragma.

```lua
local function new_conn_index(conn, key)
   local function _prag_index(_, prag)
      return _prag_set(conn, prag)
   end
   if key == "pragma" then
      return setmetatable({}, {__index = _prag_index})
   else
      return conn_mt[key]
   end
end

conn_mt.__index = new_conn_index
```
```lua
return sql
```
### Stretch goals



#### sql.NULL

This isn't much of a stretch, just a truthy table that represents nullity.


#### Dereferencing pointers in Luaspace

It would be nice to write a small C wrapper on ``sqlite3_sql()`` that gets the
address from a statement pointer and returns the resulting string.  The whole
dataflow layer of ``bridge`` is predicated on abstracting over some pretty
gnarly SQL introspection.


The easy way is just to denormalize the string onto a member of the stmt
table, but that violates single-source-of-truth, and handling pointers across
the abstraction barrier is something I'm going to need to get used to.










