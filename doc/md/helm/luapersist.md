# Table persistence via SQLite


There's doing this, and there's doing it right.


Doing this right requires Merkelizing all acyclic tables.  It is painstaking
work to define this correctly over functions, threads, userdata and C data,
and to do it over cyclic tables requires metadata.


Which is okay. A value reference to an acyclic table is prepared by Merkle
hashing and referred to by that hash inside the enclosing table.


If they have circular references these must be fixed: each value reference is
replaced with a deterministic and unique string, each table is then frozen
once the full cycle graph is resolved, and all hashes are included in the
container as resolutions of those strings.


The containers therefore have no cycles and may be hashed also. We'll need
the containing format anyway, for metatables, and any other metadata of the
sort that is deterministic to the value and not the reference or instance.


Fortunately Lua has only the one level of reference, sparing us the need to
serialize pointers to addresses and so on to the nth degree.  ``cdata`` is not
so limited...


For the near future I'm more interested in storing a naive string
representation of results, than something which can be round-tripped and
deduplicated in a generalized way, and I suspect ``fossil`` is doing a lot of
the heavy lifting for this kind of persistence already.


To get it _really_ right will involve normalizing the whitespace (but not
values) of function strings, following upvalues and tree-shaking until we
have a hash to go with each one.


The result will be pretty butch though: a SHA-3 hash that would refer to the
same object consistently across LuaJIT codebases.  Dedup and content-centric
references don't have to be just for the big bois.


The below is from the Wiki. It has some decent ideas for ordinary table
persistence, though it must be adapted to the LuaJIT SQLite library we're
using.

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

-- nb: accidentally corrupted this file (fuck) and am not using it so,
-- removed all source code -Sam
```