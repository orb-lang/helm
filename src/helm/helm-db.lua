









local uv  = require "luv"
local sql = assert(sql, "sql must be in bridge _G")
local insert = assert(table.insert)

















local Arcivist = require "sqlun:arcivist"






local helm_db = {}
-- this replaces helm_db
local helm_arc = Arcivist("/helm/helm.sqlite", "helm", 'HELM_HOME')









local helm_schema = Arcivist.schema()





















local create_project_table_3 = [[
CREATE TABLE IF NOT EXISTS project_3 (
   project_id INTEGER PRIMARY KEY AUTOINCREMENT,
   directory TEXT UNIQUE,
   time DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%f', 'now'))
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
]]






local create_project_table = [[
CREATE TABLE IF NOT EXISTS project (
   project_id INTEGER PRIMARY KEY AUTOINCREMENT,
   directory TEXT UNIQUE,
   time DATETIME DEFAULT CURRENT_TIMESTAMP
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





local migration = Arcivist.migration






helm_schema :addMigration(migration(create_project_table,
                                    create_result_table,
                                    create_repl_table,
                                    create_session_table))













local migration_3 = migration()


migration_3[1] = [[
UPDATE project
SET time = strftime('%Y-%m-%dT%H:%M:%f', time);
]]


migration_3[2] = create_project_table_3


migration_3[3] = [[
INSERT INTO project_3 (project_id, directory, time)
SELECT project_id, directory, time
FROM project;
]]

migration_3[4] = [[
DROP TABLE project;
]]

migration_3[5] = [[
ALTER TABLE project_3
RENAME TO project;
]]

migration_3[6] = [[
UPDATE repl
SET time = strftime('%Y-%m-%dT%H:%M:%f', time);
]]


migration_3[7] = create_repl_table_3


migration_3[8] = [[
INSERT INTO repl_3 (line_id, project, line, time)
SELECT line_id, project, line, time
FROM repl;
]]

migration_3[8] = [[
DROP TABLE repl;
]]

migration_3[9] = [[
ALTER TABLE repl_3
RENAME to repl;
]]


helm_schema:addMigration(migration_3)



























local migration_4 = migration()


migration_4[1] = [[
DROP TABLE session;
]]


insert(migration_4, create_session_table_4)
insert(migration_4, create_premise_table)



helm_schema:addMigration(migration_4)








local migration_5 = migration()












migration_5[1] = [[
ALTER TABLE repl RENAME TO input;
]]



migration_5[2] = [[
CREATE INDEX idx_input_time ON input (time);
]]







local create_session_table_5 = [[
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
]]






migration_5[3] = create_session_table_5


migration_5[4] = [[
INSERT INTO session_5(title, project, accepted, vc_hash)
SELECT title, project, accepted, vc_hash FROM session
;
]]

migration_5[5] = [[
DROP TABLE session;
]]

migration_5[6] = [[
ALTER TABLE session_5 RENAME TO session;
]]

















































local create_result_table_5 = [[
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
]]










local create_repr_table = [[
CREATE TABLE IF NOT EXISTS repr (
   hash TEXT PRIMARY KEY ON CONFLICT IGNORE,
   repr BLOB
);
]]



local create_repr_hash_idx = [[
CREATE INDEX repr_hash_idx ON repr (hash);
]]





migration_5[7] = create_result_table_5
migration_5[8] = create_repr_table
migration_5[9] = create_repr_hash_idx









local get_old_result_5 = [[
SELECT result_id, line_id, repr
FROM result
ORDER BY result_id
;
]]



local insert_new_result_5 = [[
INSERT INTO result_5 (result_id, line_id, hash) VALUES (?, ?, ?);
]]



local insert_repr_5 = [[
INSERT INTO repr (hash, repr) VALUES (?, ?);
]]





local drop_result_5 = [[
DROP TABLE result;
]]

local rename_result_5 = [[
ALTER TABLE result_5 RENAME TO result;
]]






local TRUNCATE_AT = 1048576 * 4 -- 4 MiB is long enough for one repr...

local function _truncate_repr(repr)
   local idx = TRUNCATE_AT
   if repr:sub(1, 1) == "\x01" then
      -- If this is a tokenized-format repr, look for the start of
      -- the next token after the 4MB mark, and stop just before it.
      -- Theoretically there might not be any such, if the repr is just
      -- barely over 4MB, in which case we keep the whole thing.
      idx = repr:find("\x01", idx, true)
      if idx then
         idx = idx - 1
      end
   end
   return repr:sub(1, idx)
end

migration_5[10] = function (conn, s)
   local sha = require "util:sha" . shorthash
   local insert_result = conn:prepare(insert_new_result_5)
   local insert_repr = conn:prepare(insert_repr_5)
   s:chat "Hashing results, this may take awhile..."
   local truncated = 0
   for _, result_id, line_id, repr in conn:prepare(get_old_result_5):cols() do
      ---[[
      if #repr > TRUNCATE_AT then
         s:verb("Found a %.2f MiB result!", #repr / 1048576)
         truncated = truncated + 1
         repr = _truncate_repr(repr)
      end
      --]]
      local hash = sha(repr)
      insert_result :bind(result_id, line_id, hash)
                    :step()
      insert_result :clearbind() :reset()
      insert_repr :bind(hash, repr) :step()
      insert_repr :clearbind() :reset()
   end
   s:chat("Truncated %d results", truncated)
   s:verb(drop_result_5)
   s:verb(rename_result_5)
   conn:exec(drop_result_5)
   conn:exec(rename_result_5)
   return true
end














helm_schema:addMigration(migration_5)






local migration_6 = migration()

































































local create_run_table = [[
CREATE TABLE IF NOT EXISTS run (
   run_id INTEGER PRIMARY KEY,
   project INTEGER NOT NULL,
   start_time DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%f', 'now')),
   finish_time DATETIME,
   FOREIGN KEY (project)
      REFERENCES project (project_id)
      ON DELETE CASCADE
);
]]

local create_run_attr_table = [[
CREATE TABLE IF NOT EXISTS run_attr (
   run_attr_id INTEGER PRIMARY KEY,
   run INTEGER,
   key TEXT,
   value BLOB,
   FOREIGN KEY (run)
      REFERENCES run (run_id)
      ON DELETE CASCADE
);
]]






















local create_run_action_table = [[
CREATE TABLE IF NOT EXISTS run_action (
   ordinal INTEGER,
   class TEXT CHECK (length(class) <= 3),
   input INTEGER,
   run INTEGER,
   PRIMARY KEY (run, ordinal) -- ON CONFLICT ABORT?
   FOREIGN KEY (run)
      REFERENCES run (run_id)
      ON DELETE CASCADE
   FOREIGN KEY (input)
      REFERENCES input (line_id)
);
]]

local create_action_attr_table = [[
CREATE TABLE IF NOT EXISTS action_attr (
   action_attr_id PRIMARY KEY,
   run_action INTEGER,
   key TEXT,
   value BLOB,
   FOREIGN KEY (run_action)
      REFERENCES run_action (run_action_id)
      ON DELETE CASCADE
);
]]









local create_error_string_table = [[
CREATE TABLE IF NOT EXISTS error_string (
   error_id INTEGER PRIMARY KEY,
   string TEXT UNIQUE ON CONFLICT IGNORE
);
]]



local create_error_string_idx = [[
CREATE INDEX idx_error_string ON error_string (string);
]]




insert(migration_6, create_run_table)
insert(migration_6, create_run_attr_table)
insert(migration_6, create_run_action_table)
insert(migration_6, create_action_attr_table)
insert(migration_6, create_error_string_table)
insert(migration_6, create_error_string_idx)



helm_schema:addMigration(migration_6)














































local historian_sql = {}





historian_sql.insert_line = [[
INSERT INTO input (project, line) VALUES (:project, :line);
]]

historian_sql.insert_result_hash = [[
INSERT INTO result (line_id, hash) VALUES (:line_id, :hash);
]]

historian_sql.insert_repr = [[
INSERT INTO repr (hash, repr) VALUES (:hash, :repr);
]]

historian_sql.insert_project = [[
INSERT INTO project (directory) VALUES (?);
]]



historian_sql.get_recent = [[
SELECT CAST (line_id AS REAL), line FROM input
   WHERE project = :project
   ORDER BY line_id DESC
   LIMIT :num_lines;
]]

historian_sql.get_number_of_lines = [[
SELECT CAST (count(line) AS REAL) from input
   WHERE project = ?
;
]]

historian_sql.get_project = [[
SELECT project_id FROM project
   WHERE directory = ?;
]]

historian_sql.get_results = [[
SELECT repr
FROM result
INNER JOIN repr ON repr.hash == result.hash
WHERE result.line_id = :line_id
ORDER BY result.result_id;
]]





helm_schema:addStatements("historian", historian_sql)













function helm_arc.historian()
   local hist_proxy = helm_arc:proxy "historian"
   local conn = helm_arc.conn
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









local session_sql = {}








session_sql.insert_session = [[
INSERT INTO
   session (title, project, accepted)
VALUES
   (:session_title, :project_id, :accepted)
;
]]

session_sql.insert_premise = [[
INSERT INTO
   premise (session, ordinal, line, title, status)
VALUES
   (:session_id, :ordinal, :line_id, :title, :status)
;
]]

session_sql.truncate_session = [[
DELETE FROM premise WHERE session = :session_id AND ordinal > :n;
]]

session_sql.delete_session_by_id = [[
DELETE FROM session WHERE session_id = :session_id;
]]



session_sql.insert_line = [[
INSERT INTO input (project, line, time) VALUES (:project, :line, :time);
]]




session_sql.insert_result_hash = historian_sql.insert_result_hash
session_sql.insert_repr        = historian_sql.insert_repr








session_sql.update_session = [[
UPDATE session SET title = :session_title, accepted = :accepted
   WHERE session_id = :session_id;
]]




session_sql.delete_session_by_id = [[
DELETE FROM session WHERE session_id = :session_id;
]]

session_sql.update_accepted_session = [[
UPDATE session SET accepted = :accepted WHERE session_id = :session_id;
]]

session_sql.update_title_session = [[
UPDATE session SET title = :title WHERE session_id = :session_id;
]]



session_sql.get_session_by_id = [[
SELECT
   session.title AS session_title,
   session.accepted AS session_accepted,
   session.session_id,
   session.project,
   premise.status,
   premise.title,
   input.line,
   input.time,
   input.line_id
FROM
   session
LEFT JOIN premise ON premise.session = session.session_id
LEFT JOIN input ON input.line_id = premise.line
WHERE session.session_id = ?
ORDER BY premise.ordinal
;
]]




session_sql.get_results = [[
SELECT repr.repr
FROM result
INNER JOIN repr ON result.hash = repr.hash
WHERE result.line_id = ?
ORDER BY result.result_id;
]]



session_sql.get_sessions_for_project = [[
SELECT title as session_title, accepted, project, vc_hash, session_id
FROM session
WHERE session.project = :project_id
ORDER BY session.session_id;
]]

session_sql.get_project_by_dir = [[
SELECT project_id FROM project WHERE directory = ?;
]]

session_sql.get_accepted_by_dir = [[
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
]]

session_sql.get_session_list_by_dir = [[
SELECT title, accepted, session_id FROM session
INNER JOIN
   project ON session.project = project.project_id
WHERE
   project.directory = ?
ORDER BY
   session.session_id
;
]]

session_sql.count_premises = [[
SELECT CAST (count(premise.ordinal) AS REAL)
FROM premise
WHERE session = :session_id
;
]]

session_sql.get_sessions_from_project = [[
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
]]

session_sql.get_sessions_by_project = [[
SELECT session_id FROM session
WHERE project = ?
ORDER BY session_id
;
]]

session_sql.get_session_by_project_and_title = [[
SELECT
   CAST (session_id AS REAL) AS session_id,
   CAST (accepted AS REAL) AS accepted
FROM session
WHERE project = ? AND title = ?
ORDER BY session_id
;
]]

session_sql.get_premises_for_export = [[
SELECT
   CAST (ordinal AS REAL) AS ordinal,
   premise.title as title,
   premise.status as status,
   input.line as line,
   input.time as time,
   input.line_id as line_id
FROM
   premise
LEFT JOIN
   input
ON
   input.line_id = premise.line
WHERE
   premise.session = :session_id
ORDER BY
   premise.ordinal
;
]]




local session_get_project_info = [[
SELECT project_id, directory from project;
]]

session_sql.update_premise_line = [[
UPDATE premise
SET line = :line
WHERE
   session = :session
AND
   ordinal = :ordinal
;
]]




helm_schema:addStatements("session", session_sql)








function helm_arc.session()
   local stmts =  helm_arc:proxy "session"
   local conn = helm_arc.conn
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








helm_arc:apply(helm_schema)




return helm_arc

