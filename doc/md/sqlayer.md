# SQLayer

This will be in pylon eventually.


Enhances the existing SQLite bindings, which in turn will be turned into a
statically-linked part of ``pylon``.

```lua
local sql = require "sqlite"
local pcall = assert (pcall)
local gsub = assert(string.gsub)
```
## sql.san(str)

Sanitizes a string for SQL(ite) quoting

```lua
function sql.san(str)
   return gsub(str, "'", "''")
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
