```lua
self = stmt.bindkv(t, prefix)
```

SQLite [parameters](https://www.sqlite.org/lang_expr.html#varparam) allow for
named parameters in several styles. For positional parameters, use `stmt:bind`
and `stmt:bind1`.

All three styles of named parameter are flexibly supported. By default, we 
use the (preferred by SQLite) form `:param`. This will bind the value of the
field `t.param`.

Example:

```lua

local obj = { r = 1.5,
              i = 12,
              s = "astr",
              b = sql.blob "bblob",
              extra = "extra fields are ignored" }

local conn = sql.open("")
conn:exec "CREATE TABLE t(r REAL, i INTEGER, s TEXT, b BLOB);"
local stmt = conn:prepare "INSERT INTO t VALUES(:r, :i, :s, :b)"
stmt:reset():bindkv(obj):step()
```

Note that the prefix parameter is optional, and can be passed explicitly:

```lua
stmt = conn:prepare "INSERT INTO t VALUES(@r, @i, @s, @b)"
stmt:reset():bindkv(obj, "@"):step()
```

If the prefix parameter is `""` the field is taken literally:

```lua
stmt = conn:prepare "INSERT INTO t VALUES(:r, :i, :s, :b)"
stmt:reset():bindkv({[":r"] = 4.5}, ""):step()
```