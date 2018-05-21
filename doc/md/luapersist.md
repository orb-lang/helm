# Table persistence via SQLite

```lua
--[[ luapersist3.lua  2004-Aug-31 e

  The author disclaims copyright to this source code.  In place of
  a legal notice, here is a blessing:
      May you be healthy and well.
      May you be free of all suffering.
      May you be happy, giving more than you take.

  Lua Persistent Tables
  loosely based on the wiki page http://lua-users.org/wiki/PersistentTables
  uses Lua SQLite 3 (see http://luaforge.net/projects/luasqlite/)
  handles circular structures

  DB Schema
  the Lua tables are stored in a single SQL table with five columns
  TID : Table ID that identifies the Lua table -- string
  Key : index in the Lua Table -- TID, string, number, or boolean
  Kyp : the data type of Key
  Val : value in the Lua Table at index -- TID, string, number, or boolean
  Vyp : the data type of Val

  A row is created for each Lua Persistent Table to reserve its TID.
  The Key, Kyp, Val, and Vyp columns are all set to "_".

  Both Kyp and Vyp use the following encoding:
  "b" -- boolean (Key/Val = "t" or "f")
  "n" -- number
  "t" -- TID
  "s" -- string
  "e" -- encoded string (the raw string has embedded NULs)
   "_" -- null

  Caveats
  1. Strings used for Key and Val may contain embedded '\0' NUL characters;
     they are stored using sqlite blobs.
     Strings used for TIDs must not have embedded NULs.
  2. A table may not be used as a key unless the table is already persistent;
      tables may always be used as vals.
  3. Functions, threads, and userdata are not supported as keys or vals.
  4. Lua Persistent Tables may not have user metatables (they will not be
     persisted, and they may conflict with Lua Persistent Table events).

  Implementation

  Lua Persistent Tables are represented by an empty Lua Table and a
  corresponding metatable.

  Lua Persistent Table Metatable events:
  "lpt_TID" -- the TID for this table
  "index" -- handler for unmarshalling Key/Val from the DB
  "newindex" -- handler for marshalling Key/Val to the DB
  "lpt_cache" -- a Lua Table that caches Key/Val pairs
  "lpt_db" -- the Lua Persistent Table database descriptor for this table's db

  LuaPersist maintains one global weak table, map, that is used to find
  Lua Persistent Tables that are already open. This insures that there
  is at most one version of each Lua Persistent Table in memory.
]]

require "sqlite3"

persist = {}

local _persist_make_TID = function (lp,tbl)
  -- return "TID"..math.random() -- fix me: confirm it's unique
  local TID
  repeat
    lp.seq = lp.seq + 1
    TID = string.format('tid%d',lp.seq)
  until(not lp:exists(TID))
  return TID
end

local _persist_val_vyp = function (lp,k)
  local ty = type(k)
  if(ty=="string") then
    if(string.find(k,"%z")) then
      return k,"e"
    else
      return k,"s"
    end
  end
  if(ty=="number") then return tostring(k),"n" end
  if(ty=="boolean") then if k then v="t" else v="f" end return v,"b" end
  if(ty=="table") then
    local mt = getmetatable(k)
    local TID
    if(mt~=nil) then TID = mt.__lpt_TID end
    if(mt==nil or TID==nil) then
      TID = _persist_make_TID(lp,k)
      local t = persist.new_table(lp,TID)
      persist.set_table(lp,TID,k)
    end
    return TID,"t"
  end
  assert(nil,"non-persistent type: "..ty.."!?")
end

local _persist_key_kyp = function (lp,k)
  if(type(k)=="table") then
    local mt = getmetatable(k)
    local TID
    if(mt~=nil) then TID = mt.__lpt_TID end
    if(mt==nil or TID==nil) then
      error("use of non-persistent table as key not supported")
    end
    return TID,"t"
  end
  return _persist_val_vyp(lp,k)
end

local _persist_raw_to_val = function (lp,ty,raw)
  if(ty=="s") then return raw end
  if(ty=="n") then return raw+0 end
  if(ty=="b") then return raw=="t" end
  if(ty=="t") then return lp:get_table(raw) end
  if(ty=="e") then return raw end
  assert(nil,"fix me -- what type is: "..ty.."?")
end

local _persist_vm_setup = function (lp,vm,TID,k)
  local key,kyp = _persist_key_kyp(lp,k) -- this must come before vm:reset since it might use vm
  assert(vm:reset()==sqlite3.OK,"db reset error")
  assert(vm:bind(1,TID)==sqlite3.OK,"db TID bind error")
  if kyp=="e"
  then
    assert(vm:bind_blob(2,key)==sqlite3.OK,"db Key bind error")
  else
    assert(vm:bind(2,key)==sqlite3.OK,"db Key bind error")
  end
  assert(vm:bind(3,kyp)==sqlite3.OK,"db Kyp bind error")
end

local _persist_index = function (t,k)
  assert(k,"key of nil not permitted")
  local ca = assert(getmetatable(t).__lpt_cache,"there is no __lpt_cache for this persistent table")
  local v = rawget(ca,k)
  if(v~=nil) then return v end
  local lp = assert(getmetatable(t).__lpt_db,"there is no __lpt_db for this persistent table")
  local TID = assert(getmetatable(t).__lpt_TID,"there is no __lpt_TID for this persistent table")
  _persist_vm_setup(lp,lp.vm_get,TID,k)
  local rc = lp.vm_get:step()
  if(rc==sqlite3.ROW) then
    local da
    da = lp.vm_get:get_values()
    lp.vm_get:reset() -- releases locks afer step
    assert(da,"db lp.vm_get:data error")
    v = _persist_raw_to_val(lp, da[2], da[1])
    rawset(ca,k,v)
  else
    lp.vm_get:reset() -- releases locks afer step
    v = nil
  end
  return v
end

local _persist_exists = function (lp,TID)
  _persist_vm_setup(lp,lp.vm_get,TID,"_")
  assert(lp.vm_get:bind(3,"_")==sqlite3.OK,"db _ bind error")
  local rc = lp.vm_get:step()
  lp.vm_get:reset() -- releases locks afer step
  return(rc==sqlite3.ROW)
end

local _persist_newindex = function (t,k,v)
  assert(k,"key of nil not permitted")
  local ca = assert(getmetatable(t).__lpt_cache,"there is no __lpt_cache for this persistent table")
  -- local pv = rawget(ca,k)
  -- if(pv~=nil) then end -- maybe remove tables -- but need gc since there may be circular refs!
  local lp = assert(getmetatable(t).__lpt_db,"there is no __lpt_db for this persistent table")
  local TID = assert(getmetatable(t).__lpt_TID,"there is no __lpt_TID for this persistent table")
  local rc, vm
  if(v~=nil) then
    local val,vyp = _persist_val_vyp(lp,v) -- this must come before vm_setup since it might use vm
    vm = lp.vm_new
    _persist_vm_setup(lp,vm,TID,k)
    if vyp=="e"
    then
        assert(lp.vm_new:bind_blob(4,val)==sqlite3.OK,"db Key bind error:"..val)
    else
        assert(lp.vm_new:bind(4,val)==sqlite3.OK,"db Key bind error:"..val)
    end
    assert(lp.vm_new:bind(5,vyp)==sqlite3.OK,"db Kyp bind error:"..vyp)
    rc = lp.vm_new:step()
  else
    vm = lp.vm_del
    _persist_vm_setup(lp,vm,TID,k)
    rc = lp.vm_del:step()
  end
  vm:reset() -- releases locks afer step
  if(rc==sqlite3.DONE) then
    rawset(ca,k,v)
  else
    error("bad result code: "..rc.."")
  end
end

local _persist_pairs = function (t)
  assert(type(t)=='table',"arg is not a table")
  local ca = assert(getmetatable(t).__lpt_cache,"arg is not a persistent table")
  return pairs(ca)
end

local _persist_check = function (lp)
  assert(lp.LPT,"the db must be opened first with persist.open")
  assert(lp.db,"the db must be opened first with persist.open")
end

persist.close = function (lp)
  _persist_check(lp)
  lp.db:close()
  lp.db=nil;
  -- nice for GC?
  lp.vm_new = nil
  lp.vm_del = nil
  lp.vm_get = nil
  lp.vm_set = nil
  lp.vm_delt = nil
  lp.map = nil
end

local _persist_new_table = function (lp,TID)
  local t = {}
  setmetatable(t,{["__lpt_db"] = lp,
                  ["__lpt_TID"] = TID,
                  ["__lpt_cache"] = {},
                  ["__index"] = _persist_index,
                  ["__newindex"] = _persist_newindex,
                  ["__unm"] = _persist_pairs})
  return t
end

persist.exists = _persist_exists

persist.new_table = function (lp,TID)
  _persist_check(lp)
  assert(lp.map[TID]==nil,"the table is already created and open")
  assert(not lp:exists(TID),"a persistent table with TID "..TID.." already exists")
  local t = _persist_new_table(lp,TID)
  assert(lp.vm_new:reset()==sqlite3.OK,"reset error")
  assert(lp.vm_new:bind(1,TID)==sqlite3.OK,"bind 1 error")
  assert(lp.vm_new:bind(2,"_")==sqlite3.OK,"bind 2 error")
  assert(lp.vm_new:bind(3,"_")==sqlite3.OK,"bind 3 error")
  assert(lp.vm_new:bind(4,"_")==sqlite3.OK,"bind 4 error")
  assert(lp.vm_new:bind(5,"_")==sqlite3.OK,"bind 5 error")
  local rc = lp.vm_new:step()
  lp.vm_new:reset() -- release locks
  if(rc==sqlite3.DONE) then
    lp.map[TID] = t
  else
    error("step error")
  end
  return t
end

persist.cache = function (lp,TID)
  _persist_check(lp)
  local t = lp.map[TID]
  assert(t~=nil,"the table does not exist")
  local ca = assert(getmetatable(t).__lpt_cache,"there is no __lpt_cache for this persistent table")
  -- whack the vm
  fn,vm,rc = lp.db:urows("SELECT Key,Kyp,Val,Vyp FROM luat where TID=?")
  assert(vm,"lp.db:rows failed")
  vm:bind(1,TID)
  for Key,Kyp,Val,Vyp in fn,vm,rc do
    if( Key ~= "_" ) then
      rawset(ca, _persist_raw_to_val(lp,Kyp,Key), _persist_raw_to_val(lp,Vyp,Val))
    end
  end
end

persist.get_table = function (lp,TID)
  _persist_check(lp)
  local t = lp.map[TID]
  if(t~=nil) then return t end
  assert(lp:exists(TID),"no persistent table has the TID "..TID)
  t = _persist_new_table(lp,TID)
  lp.map[TID] = t
  -- this needn't cache the whole table! we can make it lazy
  -- persist.cache(lp,TID)
  return t
end

persist.set_table = function (lp,TID,s)
  _persist_check(lp)
  local t = lp.map[TID]
  assert(t~=nil,"the table does not exist")
  for k,v in pairs(s) do
    t[k]=v
  end
  return t
end

persist.delete_table = function (lp,TID)
  _persist_check(lp)
  local t = lp.map[TID]
  if(t~=nil) then lp.map[TID] = nil end
  --assert(lp:exists(TID),"no persistent table has the TID "..TID)
  assert(lp.vm_delt:reset()==sqlite3.OK,"db reset error")
  assert(lp.vm_delt:bind(1,TID)==sqlite3.OK,"db TID bind error")
  local rc = lp.vm_delt:step()
  lp.vm_delt:reset() -- releases locks afer step
  return(rc)
  -- to do: what is rc supposed to be? 101
  --return t
end

persist.open = function (dbname)
  local lp = {}
  lp.LPT = true -- a tag
  lp.seq = 0 -- tid generator -- would be nice to select max (TID) where TID like 'tid%'
  lp.db = assert(sqlite3.open(dbname))
  -- initialize the db; ignore error from CREATE as it may already have been done
  local err,str = lp.db:exec("create table luat (TID,Key,Kyp,Val,Vyp, primary key (TID,Key,Kyp) on conflict replace)")
  if (err==26) then
    lp.db:close() -- bad database format
    return nil,str
  end
  lp.vm_new = assert(lp.db:compile("insert into luat values (?,?,?,?,?)"))
  lp.vm_del = assert(lp.db:compile("delete from luat where TID=? and Key=? and Kyp=?"))
  lp.vm_get = assert(lp.db:compile("select Val,Vyp from luat where TID=? and Key=? and Kyp=?"))
  --lp.vm_set = assert(lp.db:compile("update luat set Val=?,Vyp=? where TID=? and Key=? and Kyp=?"))
  lp.vm_delt = assert(lp.db:compile("delete from luat where TID=?"))
  -- convenience oo functions
  lp.new_table = persist.new_table
  lp.get_table = persist.get_table
  lp.set_table = persist.set_table
  lp.cache = persist.cache
  lp.exists = persist.exists
  lp.delete_table = persist.delete_table
  lp.close = persist.close
  -- initialize the in-memory map
  lp.map = {}
  setmetatable(lp.map,{["__mode"]="v"}) -- weak on values
  return lp
end
Examples:

require "luapersist3"

lp=assert(persist.open"ptest.db") -- or --
lp=assert(persist.open":memory:")

t=lp:new_table("foo")

assert(t==lp.map.foo)

t["baz"] = 7

for TID,Key,Kyp,Val,Vyp in lp.db:urows("SELECT * FROM luat") do
  print(TID, Key, Kyp, Val, Vyp) end

t["baz"] = 9
t["bar"] = 9
t["baz"] = 3

t.tt = {["a"]=1,["b"]=2}

tt[{1,2,3}]="t123" -- error

-- close and open

t=lp:get_table("foo")

for Key,Kyp,Val,Vyp
 in lp.db:urows("SELECT Key,Kyp,Val,Vyp FROM luat where TID='foo'")
 do print(Key, Kyp, Val, Vyp) end

lp:cache"foo"

ca = assert(getmetatable(t).__lpt_cache,"there is no __lpt_cache for this persistent table")

for k,v in pairs(ca) do print(k,v) end

=t.tt.a

t["123\000567"]="abc\000efg"

for k,v in pairs(ca)
 do local x = 0
    if(type(v)=='string') then x = string.len (v) end
    print(k,v,string.len(k),x)
 end

for Key,Kyp,Val,Vyp
 in lp.db:urows("SELECT Key,Kyp,Val,Vyp FROM luat where TID='tid1'")
 do print(Key, Kyp, Val, Vyp) end

-- debugging

for r in lp.db:nrows("SELECT * FROM SQLITE_MASTER") do
     for k,v in pairs(r) do print(k,v) end
end

-- maintanance -- LOSES ALL DATA!

for r in lp.db:nrows("DROP TABLE luat") do
     for k,v in pairs(r) do print(k,v) end
end
```
