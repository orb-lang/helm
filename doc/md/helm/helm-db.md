# Helm Database


  This module provides all the mechanisms for CRUDing the helm SQLite
database\.

```lua
local helm_db = {}
```


#### Create tables

The schema with the highest version number is the one which is current for
that table\.  The table will of course not have the `_n` suffix in the
database\.  The number is that of the migration where the table was recreated\.

Other than that, SQLite lets you add columns and rename tables\.

When this is done, it will be noted\.

```sql
CREATE TABLE IF NOT EXISTS project (
   project_id INTEGER PRIMARY KEY AUTOINCREMENT,
   directory TEXT UNIQUE,
   time DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

```sql
CREATE TABLE IF NOT EXISTS project_3 (
   project_id INTEGER PRIMARY KEY AUTOINCREMENT,
   directory TEXT UNIQUE,
   time DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%f', 'now'))
);
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

```sql
CREATE TABLE IF NOT EXISTS premise (
   session INTEGER NOT NULL,
   line INTEGER NOT NULL,
   -- order is 1-indexed for Lua compatibility
   order INTEGER NOT NULL CHECK (order > 0),
   title TEXT,
   status STRING NOT NULL CHECK (
      status = 'accept' or status = 'reject' or status = 'ignore' ),
   PRIMARY KEY (session, order) ON CONFLICT IGNORE
   FOREIGN KEY (session)
      REFERENCES session (session_id)
      ON DELETE CASCADE
   FOREIGN KEY (line)
      REFERENCES repl (line_id)
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


local function migration_2(conn)
   conn:exec(create_project_table)
   conn:exec(create_result_table)
   conn:exec(create_repl_table)
   conn:exec(create_session_table)
   return true
end

insert(migrations, migration_2)
```


#### Version 3: Millisecond\-resolution timestamps\.

  We want to accomplish two things here: change the format of all existing
timestamps, and change the default to have millisecond resolution and use
"T" instead of " " as the separator\.

SQLite being what it is, the latter requires us to copy everything to a new
table\.  This must be done for the `project` and `repl` tables\.

```lua
local function migration_3(conn)
   conn.pragma.foreign_keys(false)
   conn:exec "BEGIN TRANSACTION;"
   conn:exec [[
      UPDATE project
      SET time = strftime('%Y-%m-%dT%H:%M:%f', time);
   ]]
   conn:exec(create_project_table_3)
   conn:exec [[
      INSERT INTO project_3 (project_id, directory, time)
      SELECT project_id, directory, time
      FROM project;
   ]]
   conn:exec "DROP TABLE project;"
   conn:exec [[
      ALTER TABLE project_3
      RENAME TO project;
   ]]
   conn:exec [[
      UPDATE repl
      SET time = strftime('%Y-%m-%dT%H:%M:%f', time);
   ]]
   conn:exec(create_repl_table_3)
   conn:exec [[
      INSERT INTO repl_3 (line_id, project, line, time)
      SELECT line_id, project, line, time
      FROM repl;
   ]]
   conn:exec "DROP TABLE repl;"
   conn:exec [[
      ALTER TABLE repl_3
      RENAME to repl;
   ]]
   conn:exec "COMMIT;"
   conn.pragma.foreign_keys(true)
   return true
end
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


##### Version 5? Profiles

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

I dunno\. I've been waffling on this for months\. Ah well\.


### boot\(conn\)

`boot` takes an open `historian.conn` and brings it up to speed\.

This function has no return value\.

```lua
local assertfmt = import("core:core/string", "assertfmt")
local format = assert(string.format)

function helm_db.boot(conn)
   local HELM_DB_VERSION = helm_db.HELM_DB_VERSION
   -- Set up bridge tables
   conn.pragma.foreign_keys(true)
   conn.pragma.journal_mode "wal"
   -- check the user_version and perform migrations if necessary.
   assertfmt(#migrations == HELM_DB_VERSION,
             "number of migrations (%d) must equal HELM_DB_VERSION (%d)",
             #migrations, HELM_DB_VERSION)
   local user_version = tonumber(conn.pragma.user_version())
   if not user_version then
      user_version = 1
   end
   if user_version < HELM_DB_VERSION then
      for i = user_version + 1, HELM_DB_VERSION do
         migrations[i](conn)
      end
      conn.pragma.user_version(HELM_DB_VERSION)
   elseif user_version > HELM_DB_VERSION then
      error(format("Error: helm.sqlite is version %d, expected %d",
                   user_version, HELM_DB_VERSION))
      os.exit(HELM_DB_VERSION)
   end
end
```


```lua
return helm_db
```
