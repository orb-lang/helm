# Helm Database


  This module provides all the mechanisms for CRUDing the helm SQLite
database\.


#### imports

```lua
local uv  = require "luv"
local sql = assert(sql, "sql must be in bridge _G")
```


## helm\_db

```lua
local helm_db = {}
```


#### helm\_db\_home

```lua
local helm_db_home =  os.getenv 'HELM_HOME'
                      or _Bridge.bridge_home .. "/helm/helm.sqlite"
helm_db.helm_db_home = helm_db_home
```


#### \_conns

A weak table to hold conns, keyed by string path\.

```lua
local _conns = setmetatable({}, { __mode = 'v' })
```


#### \_resolveConn\(conn\)

A helper function to retrieve a conn if we already have one\.

Doesn't build a conn if it can't find one, and presumes that non\-string
parameters are already conns\.

```lua
local function _resolveConn(conn)
   if conn then
      if type(conn) == 'string' then
         return _conns[conn]
      else
         return conn
      end
   end
   return nil
end
```


#### \_openConn\(conn\_handle?\)

Returns an open conn, defaults to `helm_db_home`, will reuse existing conns if
it has them\.

```lua
local function _openConn(conn_handle)
   if not conn_handle then
      conn_handle = helm_db_home
   end
   local conn = _resolveConn(conn_handle)
   if not conn then
      conn = helm_db.boot(conn_handle)
   end
   assert(conn, "no conn! " .. conn_handle)
   return conn
end
```


### Create tables

The schema with the highest version number is the one which is current for
that table\.  The table will of course not have the `_n` suffix in the
database\.  The number is that of the migration where the table was recreated\.

Other than that, SQLite lets you add columns and rename tables\.

When this is done, it will be noted\.


#### Canonical

These are the current forms of each table\.


##### Project

```sql
CREATE TABLE IF NOT EXISTS project_3 (
   project_id INTEGER PRIMARY KEY AUTOINCREMENT,
   directory TEXT UNIQUE,
   time DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%f', 'now'))
);
```


##### Repl

```sql
CREATE TABLE IF NOT EXISTS repl_3 (
   line_id INTEGER PRIMARY KEY AUTOINCREMENT,
   project INTEGER,
   line TEXT,
   time DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%f', 'now')),
   FOREIGN KEY (project)
      REFERENCES project (project_id)
      ON DELETE CASCADE
);
```


##### Result

```sql
CREATE TABLE IF NOT EXISTS result (
   result_id INTEGER PRIMARY KEY AUTOINCREMENT,
   line_id INTEGER,
   repr text NOT NULL,
   value blob,
   FOREIGN KEY (line_id)
      REFERENCES repl (line_id)
      ON DELETE CASCADE
);
```


##### Session

```sql
CREATE TABLE IF NOT EXISTS session (
   session_id INTEGER PRIMARY KEY,
   title TEXT,
   project INTEGER,
   accepted INTEGER NOT NULL DEFAULT 0 CHECK (accepted = 0 or accepted = 1),
   vc_hash TEXT,
   FOREIGN KEY (project)
      REFERENCES project (project_id)
      ON DELETE CASCADE
);
```


##### Premise

```sql
CREATE TABLE IF NOT EXISTS premise (
   session INTEGER NOT NULL,
   line INTEGER NOT NULL,
   -- ordinal is 1-indexed for Lua compatibility
   -- "ordinal" not "order" because SQL
   ordinal INTEGER NOT NULL CHECK (ordinal > 0),
   title TEXT,
   status STRING NOT NULL CHECK (
      status = 'accept' or status = 'reject' or status = 'ignore' ),
   PRIMARY KEY (session, ordinal) ON CONFLICT REPLACE
   FOREIGN KEY (session)
      REFERENCES session (session_id)
      ON DELETE CASCADE
   FOREIGN KEY (line)
      REFERENCES repl (line_id)
      ON DELETE CASCADE
);
```



#### Obsolete

These are old forms of tables, which we need in order to properly migrate\.

```sql
CREATE TABLE IF NOT EXISTS project (
   project_id INTEGER PRIMARY KEY AUTOINCREMENT,
   directory TEXT UNIQUE,
   time DATETIME DEFAULT CURRENT_TIMESTAMP
);
```


```sql
CREATE TABLE IF NOT EXISTS session (
session_id INTEGER PRIMARY KEY AUTOINCREMENT,
name TEXT,
project INTEGER,
-- These two are line_ids
start INTEGER NOT NULL,
end INTEGER,
test BOOLEAN,
sha TEXT,
FOREIGN KEY (project)
   REFERENCES project (project_id)
   ON DELETE CASCADE );
```

```sql
CREATE TABLE IF NOT EXISTS repl (
   line_id INTEGER PRIMARY KEY AUTOINCREMENT,
   project INTEGER,
   line TEXT,
   time DATETIME DEFAULT CURRENT_TIMESTAMP,
   FOREIGN KEY (project)
      REFERENCES project (project_id)
      ON DELETE CASCADE
);
```


### Migrations

  We follow a simple format for migrations, incrementing the `user_version`
pragma by 1 for each alteration of the schema\.

We write a single function, which receives the database conn, for each change,
such that we should be able to take a database at any schema and bring it up
to the standard needed for this version of `helm`\.

We store these migrations in an array, such that `migration[i]` creates
`user_version` `i`\.

We skip `1` because a pragma equal to 1 is translated to the boolean `true`\.

Migrations return `true`, in case we find a migration that needs a check to
pass\.  Unless that happens, we won't bother to check the return value\.

```lua
helm_db.HELM_DB_VERSION = 3

local migrations = {function() return true end}
helm_db.migrations = migrations
```


#### Version 2: Creates tables\.

```lua
local insert = assert(table.insert)

local migration_2 = {
   create_project_table,
   create_result_table,
   create_repl_table,
   create_session_table
}

insert(migrations, migration_2)
```


#### Version 3: Millisecond\-resolution timestamps\.

  We want to accomplish two things here: change the format of all existing
timestamps, and change the default to have millisecond resolution and use
"T" instead of " " as the separator\.

SQLite being what it is, the latter requires us to copy everything to a new
table\.  This must be done for the `project` and `repl` tables\.

```lua
local migration_3 = {}
```

```sql
UPDATE project
SET time = strftime('%Y-%m-%dT%H:%M:%f', time);
```

```lua
migration_3[2] = create_project_table_3
```

```sql
INSERT INTO project_3 (project_id, directory, time)
SELECT project_id, directory, time
FROM project;
```

```sql
DROP TABLE project;
```

```sql
ALTER TABLE project_3
RENAME TO project;
```

```sql
UPDATE repl
SET time = strftime('%Y-%m-%dT%H:%M:%f', time);
```

```lua
migration_3[7] = create_repl_table_3
```

```sql
INSERT INTO repl_3 (line_id, project, line, time)
SELECT line_id, project, line, time
FROM repl;
```

```sql
DROP TABLE repl;
```

```sql
ALTER TABLE repl_3
RENAME to repl;
```

```lua
insert(migrations, migration_3)
```


#### Version 4: Sessions


##### Sessions

  The current session table is a stub, and isn't useful as is; nor is it
referred to anywhere in the codebase\.

So the first step is to drop that table, and replace it with a new one which
does\.

We add a second table, `premise`, for each line of a given session\.  This way,
a session doesn't have to be a single block of line\_ids \(which is brittle\),
but maintains its own order\.

So running a session as a test, we load all the premises into a clean
environment, executing them in order, and checking the results against the
retrieved database values\. If a premise marked as accepted = true changes, we
throw an error and \(eventually\) provide a diff\.

We'll want to add additional affordances for easy testing, which will be
documented elsewhere\.

```lua
local migration_4 = {}
```

```sql
DROP TABLE session;
```

```lua
insert(migration_4, create_session_table_4)
insert(migration_4, create_premise_table)

insert(migrations, migration_4)
```


#### Version 5

This migration will have a number of components, which we will probably need
to test in several stages, and wrap them up into a single migration\.

```lua
local migration_5 = {}
insert(migrations, migration_5)
```


##### Simple Migrations

  "Simple" in the sense that they require little\-to\-no changes to the
applications\.

The name `repl` for our collection of lines was never great, and `line` is a
reserved word in SQL, so we're already pushing our luck by having a `.line`
column\.  So we'll rename to `input`, which is simple:

```sql
ALTER TABLE repl RENAME TO input;
```

Another thing we should be adding is an index for dates on lines, like so:

```sql
CREATE INDEX idx_input_time ON input (time);
```

This is a good idea anyway, since lines are our most expensive DB call during
startup, and with sessions, lines will be placed out of order\.

We need to add an `AUTOINCREMENT` to the session table to get a stable
ordering while allowing deletions, and adding constraints means a full copy:

```sql
CREATE TABLE IF NOT EXISTS session_5 (
   session_id INTEGER PRIMARY KEY AUTOINCREMENT,
   title TEXT,
   project INTEGER,
   accepted INTEGER NOT NULL DEFAULT 0 CHECK (accepted = 0 or accepted = 1),
   vc_hash TEXT,
   FOREIGN KEY (project)
      REFERENCES project (project_id)
      ON DELETE CASCADE
);
```

We'll move this to the top once this migration is complete; it's more
important to have an at\-a\-glance view into the schema, and we don't have
transclusions yet\.

```lua
migration_5[3] = create_session_table_5
```

```sql
INSERT INTO session_5(title, project, accepted, vc_hash)
SELECT title, project, accepted, vc_hash FROM session
;
```

```sql
DROP TABLE session;
```

```sql
ALTER TABLE session_5 RENAME TO session;
```


##### hashing and de\-duplication of results \(w\. truncation\)

We want to start storing results as the hash of the repr string, and use that
as the foreign key into a new table, `repr`\.

There are a number of circumstances where we will only need the hash, and by
making the hash column of `repr` a `UNIQUE`, we can get deduplication
without needing to handle it in\-memory\.

This does mean we have to pull every result, hash it, update the result
foreign key to point to the result, and commit to a new table\.

While we're at this, it might pay off to truncate our absurdly long results\.

It's likely I have the only database which *has* a large result collection, so
maybe not worth the extra complexity? But I have a GB or so of data in my helm
DB, and it's not *that* much extra work\.

One minor optimization: we don't actually have to hash results which are
smaller than 64 bytes, the length of our hash\.  We can simply treat the repr
as the hash, and commit it twice to the database, and this will save some tiny
amount of space\.  There are circumstances when we pull the repr \(and hence the
hash\) without pulling the result right away, and if the result is less than 63
bytes, we know we don't have to bother with the second database call\.

I'm not convinced this is worth doing, but, I'm not convinced it isn't\.  The
important part is that we can completely ignore this logic if we want to, and
get the same result, as long as we bake the conditional hashing into a
function and use that function everywhere we hash: and we're truncating
anyway, relative to stock sha3\-512\.

For reference, here's the current schema of `result`:

```sql
CREATE TABLE IF NOT EXISTS result (
   result_id INTEGER PRIMARY KEY AUTOINCREMENT,
   line_id INTEGER,
   repr text NOT NULL,
   value blob,
   FOREIGN KEY (line_id)
      REFERENCES repl (line_id)
      ON DELETE CASCADE
);
```

Our new version looks like this:

```sql
CREATE TABLE IF NOT EXISTS result_5 (
   result_id INTEGER PRIMARY KEY AUTOINCREMENT,
   line_id INTEGER,
   hash text NOT NULL,
   FOREIGN KEY (line_id)
      REFERENCES input (line_id)
      ON DELETE CASCADE
   FOREIGN KEY (hash)
      REFERENCES repr (hash)
);
```

Although it might be worth it to create a whole new `input` table, rather than
using `ALTER TABLE`, simply to change the foreign key to `input_id`\.

And we need our `repr` table as well:

```sql
CREATE TABLE IF NOT EXISTS repr (
   hash TEXT PRIMARY KEY ON CONFLICT IGNORE,
   repr BLOB
);
```

Which should have an index on hash:

```sql
CREATE INDEX repr_hash_idx ON repr (hash);
```

Now for the fun part: we need a function which will create the new table,
select every line, hash the `repr` field, write the new hash and repr to
`repr`, and write the rest of the contents to `result_5`, then drop `result`
and rename\.

We want the results in order of entry:

```sql
SELECT result_id, line_id, repr
FROM result
ORDER BY result_id
;
```

We never used `value` for anything, so we can safely leave it behind\.

To put it back:

```sql
INSERT INTO result_5 (result_id, line_id, hash) VALUES (?, ?, ?);
```

To write the hash:

```sql
INSERT INTO repr (hash, repr) VALUES (?, ?);
```

Letting our ON CONFLICT IGNORE perform deduplication\.

Then drop and rename:

```sql
DROP TABLE result;
```

```sql
ALTER TABLE result_5 RENAME TO result;
```

Now we tie it all together in a function\.  `sha` is required locally, because
migrations are run seldom; by the nature of `valiant` and `helm`, we'll need
the function elsewhere, but this is good practice\.

```lua
local function migrate_result_5(conn)
   local sha = require "util:sha" . shorthash
   local insert_result = conn:prepare(insert_new_result_5)
   local insert_repr = conn:prepare()
   for result_id, line_id, repr in conn:prepare(get_old_result_5):cols() do
      local hash = sha(repr)
      insert_result :bind(result_id, line_id, hash)
                    :step() :clearbind() :reset()
      insert_repr :bind(hash, repr) :step() :clearbind() :reset()
   end
   conn:exec(drop_result_5)
   conn:exec(rename_result_5)
   return true
end

-- migration_5[7] = migrate_result_5
```

It will be interesting to see if this actually makes my database smaller\.  It
seems likely, but it triples the size of small, unique values, and only
shrinks the storage requirement for larger prints\.  But I must have a few
hundred copies of `uv` alone in there\.  We'll see\.


##### run table

It has become clear that we need a concept of a 'run', distinct from sessions\.

A run is simply everything which happens from starting helm to closing it\.

At present, it's unclear to me precisely how to model this\. The model for the
`input` table is straightforward, although we're doing deduplication if a line
is executed multiple times in a row, in a way we actually shouldn't: but
conceptually, `input` is a simple linear collection of lines executed from the
helm\.

Runs, at a base level, are a collection of lines, but there is also metadata
we want to preserve\.  In particular, the point at which a restart is triggered,
but I would be surprised if that is the full extent of what we want to
preserve\.

What is clear enough is that we have two tables, `run` and `run_action`\.  We
have one entry in `run` per execution of `helm`, and the contents are stored
in `run_action`\.  Since most of these are lines, we want a `input` foreign key,
which can be null, to represent the most common case, and we can probably get
by with one more column \(perhaps `run_action.action`?\) which is a string which
represents the type of action\.  I've been using short, human\-readable strings
for this sort of data, but it's probably better to use a single byte of ASCII
and rehydrate the data in\-memory\.  SQLite doesn't reserve disk space it isn't
using, and there's an appreciable difference between storing `'line'` and
`'restart'` versus merely `'l'` and `'r'`\.

Like premises, our best bet is to make the foreign key for `run` a tuple of
`(input, ordinal)`, since we'll be recording every meaningful action in order\.

I don't know if there's a way to enforce "every ordinal for a given repr must
be monotonic and increasing, starting with 1" from within SQLite, but it seems
like a common enough pattern and would be nice to have, so I'll look into it\.

Our constraint for `.action` should be a string of length 1, that gives us
plenty of flexibility while still failing on most accidental data we might
provide to the column\.

What fields we include in the `run` table itself is also an open question, and
I'm tempted to create a `run_eav` table which just holds arbitrary key/values
for a given run, as a species of future\-proofing\.  A little lazy, but not
exceptionally so, and we don't have the prerequisites in place to store and
retrieve JSON, which is a pity\.


### Future Migrations

Right now, `helm` is omokase: you get some readline commands, and you get the
colors we give you, and that's that\.

In the near future, we intend to add persistent user preferences, starting
with color schemes\.

There are a lot of unanswered questions about how to do this in a general way\.
The standard approach is config files, and that has a lot to recommend it\.

For color schemes, however, we're going to put them in the database, and we
might continue in that vein\.  This will take the form of an EAV table called
`preference`, which starts with one value, a foreign key to the
`color_profile` table\.  The `color` table is a number of colors with a name
and a foreign key to `color_profile`\.

Hmm\.  The more I think about this, it seems less than ideal\.  The alternative
being a simple orb file with Lua tables in it, which is easier to inspect and
modify\.  I want the user to be able to change colors inside `helm` and have
those changes persist, but this isn't impossible or even that difficult to
do with Lua files\.

I just wrote a TOML parser for use in the manifest files, so that's a good
candidate for configuration data now\.

I dunno\. I've been waffling on this for months\. Ah well\.


## Statement proxy tables

  We retain the conns within the `helm_db` singleton, returning a proxy table
to consumers, which can be indexed to obtain fresh prepared statements\.

These tables will also be equipped with functions which close over the conn to
execute operations, particularly transactions, which require the use of
`conn:exec`\.

```lua
local function _prepareStatements(conn, stmts)
   return function(_, key)
      if stmts[key] then
         return conn:prepare(stmts[key])
      else
         error("Don't have a statement " .. key .. " to prepare.")
      end
   end
end

local function _readOnly(_, key, value)
   error ("can't assign to prepared statements table, key: " .. key
          .. " value: " .. value)
end

local lastRowId = assert(sql.lastRowId)
function _makeProxy(conn, stmts)
   return setmetatable({ lastRowId = function() return lastRowId(conn) end },
                       { __index = _prepareStatements(conn, stmts),
                         __newindex = _readOnly })
end
```


### Historian

  Generates prepared statements and contains closures for the necessary
savepoints to operate [historian](@:helm/historian)\.


#### Historian SQL statements

```lua
local historian_sql = {}
helm_db.historian_sql = historian_sql
```


##### Insertions

```sql
INSERT INTO input (project, line) VALUES (:project, :line);
```

```sql
INSERT INTO result (line_id, repr) VALUES (:line_id, :repr);
```

```sql
INSERT INTO project (directory) VALUES (?);
```

```sql
INSERT INTO session (title, project, accepted) VALUES (?, ?, ?);
```

```sql
INSERT INTO
   premise (session, line, ordinal, title, status)
VALUES
   (?, ?, ?, ?, ?);
```


##### Selections

```sql
SELECT CAST (line_id AS REAL), line FROM input
   WHERE project = :project
   ORDER BY line_id DESC
   LIMIT :num_lines;
```

```sql
SELECT CAST (count(line) AS REAL) from input
   WHERE project = ?
;
```

```sql
SELECT project_id FROM project
   WHERE directory = ?;
```

```sql
SELECT result.repr
FROM result
WHERE result.line_id = :line_id
ORDER BY result.result_id;
```


#### helm\_db\.historian\(conn?\)

  Returns a table of the necessary prepared statements, and closures, for
`historian` to conduct database operations\.  `conn` defaults to the system
helm\_db\.

```lua
function helm_db.historian(conn_handle)
   local conn = _openConn(conn_handle)
   local hist_proxy = _makeProxy(conn, historian_sql)
   rawset(hist_proxy, "savepoint_persist",
          function()
            conn:exec "SAVEPOINT save_persist"
          end)
   rawset(hist_proxy, "release_persist",
          function()
             conn:exec "RELEASE save_persist"
          end)
   rawset(hist_proxy, "savepoint_restart_session",
          function()
             conn:exec "SAVEPOINT restart_session"
          end)
   rawset(hist_proxy, "release_restart_session",
          function()
             conn:exec "RELEASE restart_session"
          end)
   return hist_proxy
end
```


### Session

  The `helm_db` singleton is also used by [valiant](@valiant:session) to
manage database operations, through the same sort of proxy table as above\.

@Daniel
which is currently in historian into the historian table, just for convenience\.

```lua
local session_sql = {}
```

#### SQL

```sql
SELECT
   session.title AS session_title,
   session.session_id,
   session.project,
   premise.ordinal,
   premise.status,
   premise.title,
   input.line,
   input.time,
   input.line_id
FROM
   session
INNER JOIN premise ON premise.session = session.session_id
INNER JOIN input ON input.line_id = premise.line
WHERE session.session_id = ?
ORDER BY premise.ordinal
;
```

Because the results have a many\-to\-one relationship with the lines, we're
better off retrieving them separately:

```sql
SELECT result.repr
FROM result
WHERE result.line_id = ?
ORDER BY result.result_id;
```

```sql
SELECT project_id FROM project WHERE directory = ?;
```

```sql
SELECT title FROM session
INNER JOIN
   project ON session.project = project.project_id
WHERE
   project.directory = ?
AND
   session.accepted = 1
ORDER BY
   session.session_id
;
```

This one is a `conn:exec` so we use a closure, rather than a prepared
statement\.

```sql
SELECT project_id, directory from project;
```

```sql
SELECT
   session_id,
   CAST(accepted AS REAL) As accepted
FROM
   session
WHERE
   project = ?
ORDER BY
   session.session_id
;
```

```sql
SELECT session_id FROM session
WHERE project = ?
ORDER BY session_id
;
```

```sql
UPDATE premise
SET line = :line
WHERE
   session = :session
AND
   ordinal = :ordinal
;
```

```sql
INSERT INTO
   input (project, line, time)
VALUES (?, ?, ?)
;
```


##### Shared SQL

We copy over a few statements from the historian proxy table\.

```lua
session_sql.insert_result = historian_sql.insert_result
```

```lua
function helm_db.session(conn_handle)
   local conn = _openConn(conn_handle)
   local stmts =  _makeProxy(conn, session_sql)
   rawset(stmts, "get_project_info",
          function()
             return conn:exec(session_get_project_info)
          end)
   rawset(stmts, "beginTransaction",
          function()
             return conn:exec "BEGIN TRANSACTION;"
          end)
   rawset(stmts, "commit",
          function()
             return conn:exec "COMMIT;"
          end)
   return stmts
end
```


### boot\(conn\_handle?\)

`boot` takes an open `historian.conn`, or a file path, and brings it up to
speed\.

Returns the conn, or errors and exits the program\.

```lua
local assertfmt = require "core:core/string" . assertfmt
local format = assert(string.format)
local boot = assert(sql.boot)


function helm_db.boot(conn_handle)
   local conn = _resolveConn(conn_handle)
   if not conn then
      conn_handle = helm_db_home
      conn = boot(conn_handle, migrations)
      _conns[conn_handle] = conn
   end

   return conn
end
```


### close\(conn\_handle?\)

Closes the given conn or conn\-string, defaulting to the helm\_db\_home conn\.

```lua
function helm_db.close(conn_handle)
   local conn = _resolveConn(conn_handle)
   if not conn then
      conn = _conns[helm_db_home]
      conn_handle = helm_db_home
   end
   if not conn then return end
   pcall(conn.pragma.wal_checkpoint, "0") -- 0 == SQLITE_CHECKPOINT_PASSIVE
   -- set up an idler to close the conn, so that e.g. busy
   -- exceptions don't blow up the hook
   local close_idler = uv.new_idle()
   close_idler:start(function()
      local success = pcall(conn.close, conn)
      if not success then
         return nil
      else
         -- we don't want to rely on GC to prevent closing a conn twice
         _conns[conn_handle] = nil
         close_idler:stop()
      end
   end)
end
```


### conn\(conn\_handle?\)

Retrieve a conn, defaulting as usual to `helm_db_home`, if one already exists\.

Primarily for use at the REPL\.

```lua
function helm_db.conn(conn_handle)
   conn_handle = conn_handle or helm_db_home
   return _conns[conn_handle]
end
```


#### protect helm\_db

As a singleton, it should be read only\.

```lua
setmetatable(helm_db, { __newindex = function()
                                        error "cannnot assign to helm_db"
                                     end })
```


```lua
return helm_db
```
