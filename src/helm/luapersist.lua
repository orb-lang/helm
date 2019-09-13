










































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

-- nb: accidentally corrupted this file (fuck) and am not using it so,
-- removed all source code -Sam
