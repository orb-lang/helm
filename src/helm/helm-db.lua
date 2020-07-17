






local helm_db = {}













local create_project_table = [[
CREATE TABLE IF NOT EXISTS project (
   project_id INTEGER PRIMARY KEY AUTOINCREMENT,
   directory TEXT UNIQUE,
   time DATETIME DEFAULT CURRENT_TIMESTAMP
);
]]

local create_project_table_3 = [[
CREATE TABLE IF NOT EXISTS project_3 (
   project_id INTEGER PRIMARY KEY AUTOINCREMENT,
   directory TEXT UNIQUE,
   time DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%f', 'now'))
);
]]

local create_repl_table = [[
CREATE TABLE IF NOT EXISTS repl (
   line_id INTEGER PRIMARY KEY AUTOINCREMENT,
   project INTEGER,
   line TEXT,
   time DATETIME DEFAULT CURRENT_TIMESTAMP,
   FOREIGN KEY (project)
      REFERENCES project (project_id)
      ON DELETE CASCADE
);
]]

local create_repl_table_3 = [[
CREATE TABLE IF NOT EXISTS repl_3 (
   line_id INTEGER PRIMARY KEY AUTOINCREMENT,
   project INTEGER,
   line TEXT,
   time DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%f', 'now')),
   FOREIGN KEY (project)
      REFERENCES project (project_id)
      ON DELETE CASCADE
);
]]

local create_result_table = [[
CREATE TABLE IF NOT EXISTS result (
   result_id INTEGER PRIMARY KEY AUTOINCREMENT,
   line_id INTEGER,
   repr text NOT NULL,
   value blob,
   FOREIGN KEY (line_id)
      REFERENCES repl (line_id)
      ON DELETE CASCADE
);
]]

local create_session_table = [[
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
]]

local create_session_table_4 = [[
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
]]

local create_premise_table = [[
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
]]




















helm_db.HELM_DB_VERSION = 3

local migrations = {function() return true end}
helm_db.migrations = migrations






local insert = assert(table.insert)


local function migration_2(conn)
   conn:exec(create_project_table)
   conn:exec(create_result_table)
   conn:exec(create_repl_table)
   conn:exec(create_session_table)
   return true
end

insert(migrations, migration_2)






















































local migration_3 = {}


local migration_3 = [[
UPDATE project
SET time = strftime('%Y-%m-%dT%H:%M:%f', time);
]]


migration_3[2] = create_project_table_3


local migration_3 = [[
INSERT INTO project_3 (project_id, directory, time)
SELECT project_id, directory, time
FROM project;
]]

local migration_3 = [[
DROP TABLE project;
]]

local migration_3 = [[
ALTER TABLE project_3
RENAME TO project;
]]

local migration_3 = [[
UPDATE repl
SET time = strftime('%Y-%m-%dT%H:%M:%f', time);
]]


migration_3[7] = create_repl_table_3


local migration_3 = [[
INSERT INTO repl_3 (line_id, project, line, time)
SELECT line_id, project, line, time
FROM repl;
]]

local migration_3 = [[
DROP TABLE repl;
]]

local migration_3 = [[
ALTER TABLE repl_3
RENAME to repl;
]]


insert(migrations, migration_3)



























































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




return helm_db
