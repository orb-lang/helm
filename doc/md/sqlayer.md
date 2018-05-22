# SQLayer

This will be in pylon eventually.


Enhances the existing SQLite bindings, which in turn will be turned into a
statically-linked part of ``pylon``.

```lua
local sql = require "sqlite"
local pcall = assert (pcall)
local gsub = assert(string.gsub)
local format = assert(string.format)
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
SQLite binds. In the meantime we're going to use format strings, which at
least typecheck parameters.


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
function sql.pexec(conn, stmt)
   -- conn:exec(stmt)
   local success, value = pcall(conn.exec, conn, stmt)
   if success then
      return value
   else
      return false, value
   end
end
```
```lua
return sql
```