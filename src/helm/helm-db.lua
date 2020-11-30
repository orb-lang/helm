









local uv  = require "luv"
local sql = assert(sql, "sql must be in bridge _G")






local helm_db = {}






local helm_db_home =  os.getenv 'HELM_HOME'
                      or _Bridge.bridge_home .. "/helm/helm.sqlite"
helm_db.helm_db_home = helm_db_home








local _conns = setmetatable({}, { __mode = 'v' })











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




















helm_db.HELM_DB_VERSION = 3

local migrations = {function() return true end}
helm_db.migrations = migrations






local insert = assert(table.insert)

local migration_2 = {
   create_project_table,
   create_result_table,
   create_repl_table,
   create_session_table
}

insert(migrations, migration_2)













local migration_3 = {}


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


insert(migrations, migration_3)



























local migration_4 = {}


migration_4[1] = [[
DROP TABLE session;
]]


insert(migration_4, create_session_table_4)
insert(migration_4, create_premise_table)

insert(migrations, migration_4)








local migration_5 = {}
insert(migrations, migration_5)












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
   for result_id, line_id, repr in conn:prepare(get_old_result_5):cols() do
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












local historian_sql = {}
helm_db.historian_sql = historian_sql





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









local session_sql = {}






session_sql.insert_session = [[
INSERT INTO
  session (title, project, accepted)
VALUES
  (:session_title, :project_id, :accepted);
]]

session_sql.insert_premise = [[
INSERT INTO
   premise (session, ordinal, line, title, status)
VALUES
   (:session_id, :ordinal, :line_id, :title, :status);
]]

session_sql.truncate_session = [[
DELETE FROM premise WHERE session = :session_id AND ordinal > :n;
]]






session_sql.update_session = [[
UPDATE session SET title = :session_title, accepted = :accepted
   WHERE session_id = :session_id;
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
INNER JOIN premise ON premise.session = session.session_id
INNER JOIN input ON input.line_id = premise.line
WHERE session.session_id = ?
ORDER BY premise.ordinal
;
]]




session_sql.get_results = [[
SELECT result.repr
FROM result
WHERE result.line_id = ?
ORDER BY result.result_id;
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
SELECT CAST (session_id AS REAL) FROM session
WHERE project = ? AND title = ?
ORDER BY session_id
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

session_sql.insert_line = [[
INSERT INTO
   input (project, line, time)
VALUES (?, ?, ?)
;
]]







session_sql.insert_result = historian_sql.insert_result



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










function helm_db.conn(conn_handle)
   conn_handle = conn_handle or helm_db_home
   return _conns[conn_handle]
end








setmetatable(helm_db, { __newindex = function()
                                        error "cannnot assign to helm_db"
                                     end })




return helm_db

