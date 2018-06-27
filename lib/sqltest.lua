local TS = tostring

local function T_eq(...) -- Test all equal between them.
  local args = {...}
  for i=2,#args do
    assert(args[i-1] == args[i] and type(args[i-1]) == type(args[i]),
      TS(args[i-1])..TS(args[i]))
  end
end

local function T_eqv(a, b) -- Test two vectors are equal.
  assert(#a == #b)
  for i=1,#a do T_eq(a[i], b[i]) end
end

--------------------------------------------------------------------------------
local sql = require "sqlite"

-- Open.
local conn = sql.open("")

-- Exec without return.
conn:exec "CREATE TABLE t(r REAL, i INTEGER, s TEXT, b BLOB);"
conn:exec "INSERT INTO t VALUES(1.0, 1, 'atext', CAST('ablob' AS BLOB))"

-- Rowexec.
T_eqv({conn:rowexec "SELECT typeof(r),typeof(i),typeof(s),typeof(b),* FROM t"},
      {"real", "integer", "text", "blob", 1, 1LL, "atext", "ablob"})

do -- Exec with return and multiple commands.
conn:exec [[
INSERT INTO t VALUES(2.0, 2, 'btext', CAST('bblob' AS BLOB));
INSERT INTO t VALUES(3.0, 3, 'ctext', CAST('cblob' AS BLOB));
]]
local ret, n = conn:exec "SELECT * FROM t"
T_eq(n, 3, #ret.r)
T_eq(#ret, 4)
T_eqv(ret.s, ret[3])
T_eqv(ret.i, {1LL, 2LL, 3LL})
end

do -- Exec with customised get.
local ret, n = conn:exec("SELECT * FROM t", "h")
T_eqv(ret[0], {"r", "i", "s", "b"})
T_eq(ret[2], nil)
T_eq(ret.i, nil)
local ret, n = conn:exec("SELECT * FROM t", "i")
T_eq(ret[0], nil)
T_eqv(ret[2], {1LL, 2LL, 3LL})
T_eq(ret.i, nil)
local ret, n = conn:exec("SELECT * FROM t", "k")
T_eq(ret[0], nil)
T_eq(ret[2], nil)
T_eqv(ret.i, {1LL, 2LL, 3LL})
end

-- Call.
conn "SELECT * FROM t"

-- Setscalar.
conn:setscalar("MYF", math.exp)
T_eq(conn:rowexec "SELECT MYF(r) FROM t LIMIT 1", math.exp(1))
conn:setscalar("MYF", math.sqrt)
T_eq(conn:rowexec "SELECT MYF(r) FROM t LIMIT 1", math.sqrt(1))
conn:setscalar("MYF") -- Remove MYF from SQLite3 and free callback.

-- Setaggregate.
conn:setaggregate("MYAF",
  function() return { sum = 0 } end, -- Can be a "class" as well :-)
  function(self, x) self.sum = self.sum + x end,
  function(self) return self.sum end
)
T_eq(conn:rowexec "SELECT MYAF(r) FROM t", 6)
T_eq(conn:rowexec "SELECT SUM(r)  FROM t", 6) -- We knew it :P
conn:setaggregate("MYAF") -- Remove MYAF from SQLite3 and free callback.

-- Prapare.
local stmt = conn:prepare "INSERT INTO t VALUES(?, ?, ?, ?)"


do -- Bindings, reset, step.
conn:exec "DELETE FROM t"
stmt:reset():bind(1, 1, "astr", "astr"):step()
stmt:reset():bind(2, 2, "bstr", sql.blob("bblob")):step()
stmt:reset():step()
stmt:reset():bind1(2, 4LL):step()
stmt:reset():clearbind():bind1(2, 5LL):step()
local ret, n = conn:exec "SELECT *, typeof(b) FROM t"
T_eq(n, 5, #ret.i)
T_eq(#ret, 5)
T_eqv(ret.s, ret[3])
T_eqv(ret.i, {1LL, 2LL, 2LL, 4LL, 5LL})
T_eqv(ret["typeof(b)"], {"text", "blob", "blob", "blob", "null"})
end

local stmt_kv = conn:prepare "INSERT INTO t VALUES(:r, :i, :s, :b)"

-- Tests for bindkv
do -- Bindings, reset, step.
conn:exec "DELETE FROM t"
stmt_kv:reset():bindkv {r = 1, i = 1, s = "astr", b = "astr"} :step()
stmt_kv:reset():bindkv {r = 2, i = 2, s = "bstr", b = sql.blob("bblob")} :step()
local ret, n = conn:exec "SELECT *, typeof(b) FROM t"
T_eq(#ret, 5)
T_eqv(ret.b[1], "astr")
T_eqv(ret.b[2], "bblob")
T_eqv(ret["typeof(b)"], {"text", "blob"})
end

-- Close.
conn:close()