





























local create_project_table_7 = [[
CREATE TABLE project_copy(
   project_id INTEGER PRIMARY KEY,
   directory TEXT,
   name TEXT,
   fact LUATEXT
);
]]






local create_line_table_7 = [[
CREATE TABLE line (
   line_id INTEGER PRIMARY KEY,
   string TEXT UNIQUE NOT NULL,
   hash TEXT,
);

CREATE INDEX line_text_id ON line (string);
CREATE INDEX line_hash_id ON line (hash);
]]




























































local create_round_table_7 = [[
CREATE TABLE round(
   round_id INTEGER PRIMARY KEY,
   line INTEGER NOT NULL,
   response INTEGER NOT NULL,
   FOREIGN KEY (line)
      REFERENCES line (line_id)
   FOREIGN KEY (response)
      REFERENCES response (response_id)
);
]]

































local create_response_table_7 = [[
CREATE TABLE response(
   response_id INTEGER PRIMARY KEY
);
]]





























local create_result_table_7 = [[
CREATE TABLE IF NOT EXISTS result_copy (
   result_id INTEGER PRIMARY KEY,
   response INTEGER NOT NULL,
   ordinal INTEGER NOT NULL CHECK (order > 0),
   hash TEXT NOT NULL,
   UNIQUE(response, ordinal)
   FOREIGN KEY (response)
      REFERENCES response (response_id)
      ON DELETE CASCADE
   FOREIGN KEY (hash)
      REFERENCES repr (hash)
);
]]

























local create_repr_table_7 = [[
CREATE TABLE repr_copy (
   hash TEXT PRIMARY KEY ON CONFLICT IGNORE,
   repr BLOB
);
]]








local create_riff_table_7 = [[
CREATE TABLE riff (
   riff_id INTEGER PRIMARY KEY,
);
]]










local create_riff_round_table_7 = [[
CREATE TABLE riff_round(
   riff_round_id INTEGER PRIMARY KEY,
   riff INTEGER NOT NULL,
   ordinal INTEGER NOT NULL CHECK (order > 0),
   round INTEGER NOT NULL
   UNIQUE (riff, ordinal)
   FOREIGN KEY (riff)
      REFERENCES riff (riff_id)
   FOREIGN KEY (round)
      REFERENCES round (round_id)
);
]]













local create_run_table_7 = [[
CREATE TABLE run_copy (
   run_id INTEGER PRIMARY KEY,
   project INTEGER NOT NULL,
   start_time DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%f', 'now')),
   finish_time DATETIME,
   latest_riff INTEGER,
   FOREIGN KEY (project)
      REFERENCES project (project_id)
      ON DELETE CASCADE
   FOREIGN KEY (latest_riff)
      REFERENCES riff (riff_id)
);
]]






























local create_run_action_table_7 = [[
CREATE TABLE run_action_copy (
   run_action_id INTEGER PRIMARY KEY AUTOINCREMENT,
   class TEXT CHECK (length(class) <= 3),
   time DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%f', 'now')),
   round INTEGER,
   run INTEGER NOT NULL,
   fact LUATEXT,
   FOREIGN KEY (run)
      REFERENCES run (run_id)
      ON DELETE CASCADE
   FOREIGN KEY (round)
      REFERENCES round (round_id)
);
]]















local create_error_text_table_7 = [[
CREATE TABLE error_text (
   error_line_id INTEGER PRIMARY KEY,
   error TEXT UNIQUE NOT NULL,
   hash TEXT NOT NULL -- trust me, SQLite: it's UNIQUE
); -- index me
]]

local create_error_table_7 = [[
CREATE TABLE error(
   error_id INTEGER PRIMARY KEY,
   response INTEGER, -- NOT NULL? maybe
   short INTEGER,
   error INTEGER NOT NULL,
   FOREIGN KEY response
      REFERENCES response (response_id)
   FOREIGN KEY error_text
      REFERENCES error_text (error_text_id)
   FOREIGN KEY short
      REFERENCES error_text(error_text_id)
);
]]




























local create_status_response_table_7 = [[
CREATE TABLE status_response(
   status_response_id INTEGER PRIMARY KEY,
   response INTEGER NOT NULL,
   category TEXT NOT NULL,
   FOREIGN KEY response
      REFERENCES response (response_id)
);
]]






















local create_session_table_7 = [[
CREATE TABLE session_copy (
   session_id INTEGER PRIMARY KEY,
   title TEXT,
   doc INTEGER,
   doc_hash TEXT,
   project INTEGER,
   active INTEGER NOT NULL DEFAULT 0 CHECK (active = 0 or active = 1),
   riff INTEGER NOT NULL,
   fact LUATEXT,
   FOREIGN KEY (project)
      REFERENCES project (project_id)
   FOREIGN KEY (riff)
      REFERENCES riff (riff_id)
);
]]


























local create_premise_table_7 = [[
CREATE TABLE premise_copy (
   premise_id INTEGER PRIMARY KEY,
   session INTEGER NOT NULL,
   riff_round INTEGER NOT NULL,
   premise INTEGER NOT NULL,
   normal INTEGER CHECK (normal = 0 OR normal = 1) DEFAULT 1,
   status STRING NOT NULL CHECK (
      status = 'accept' or status = 'watch' or status = 'ignore' ),
   FOREIGN KEY (session)
      REFERENCES session (session_id)
   FOREIGN KEY (riff_round)
      REFERENCES riff_round (riff_round_id)
   FOREIGN KEY (premise)
      REFERENCES line (line_id)
);
]]








































local migration_7_get_rows = [[
SELECT
   input.line as line,
   input.time as time,
   premise.session as session_id,
   premise.ordinal as premise_order,
   premise.title as premise,
   premise.status as status,
   result.hash as shorthash,
   repr.repr as repr,
   run_action.run as run_id
FROM
   input
LEFT JOIN premise on premise.line = input.line_id
LEFT JOIN result on result.line_id = input.line_id
LEFT JOIN repr on result.hash = repr.hash
LEFT JOIN run_action on run_action.input = input.line_id
WHERE
   project = :project_id
;
]]
