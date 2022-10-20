k\* Helm DB Schema


  It's gotten intractable to tell the current schema from the latest table
creation string\.  We've used ALTER TABLE, and we'll start using ALTER COLUMN
eventually as well\.

So this is just a copy\-paste of the schema, straight from the database, which
we'll replace after each migration\.

This is the schema as of migration 6\.

```sql
CREATE TABLE IF NOT EXISTS "project" (
   project_id INTEGER PRIMARY KEY AUTOINCREMENT,
   directory TEXT UNIQUE,
   time DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%f', 'now'))
);
CREATE TABLE sqlite_sequence(name,seq);
CREATE TABLE IF NOT EXISTS "input" (
   line_id INTEGER PRIMARY KEY AUTOINCREMENT,
   project INTEGER,
   line TEXT,
   time DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%f', 'now')),
   FOREIGN KEY (project)
      REFERENCES project (project_id)
      ON DELETE CASCADE
);
CREATE TABLE premise (
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
      REFERENCES "input" (line_id)
      ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS "session" (
   session_id INTEGER PRIMARY KEY AUTOINCREMENT,
   title TEXT,
   project INTEGER,
   accepted INTEGER NOT NULL DEFAULT 0 CHECK (accepted = 0 or accepted = 1),
   vc_hash TEXT,
   FOREIGN KEY (project)
      REFERENCES project (project_id)
      ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS "result" (
   result_id INTEGER PRIMARY KEY AUTOINCREMENT,
   line_id INTEGER,
   hash text NOT NULL,
   FOREIGN KEY (line_id)
      REFERENCES input (line_id)
      ON DELETE CASCADE
   FOREIGN KEY (hash)
      REFERENCES repr (hash)
);
CREATE TABLE repr (
   hash TEXT PRIMARY KEY ON CONFLICT IGNORE,
   repr BLOB
);
CREATE TABLE run (
   run_id INTEGER PRIMARY KEY,
   project INTEGER NOT NULL,
   start_time DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%f', 'now')),
   finish_time DATETIME,
   FOREIGN KEY (project)
      REFERENCES project (project_id)
      ON DELETE CASCADE
);
CREATE TABLE run_attr (
   run_attr_id INTEGER PRIMARY KEY,
   run INTEGER,
   "key" TEXT,
   value BLOB,
   FOREIGN KEY (run)
      REFERENCES run (run_id)
      ON DELETE CASCADE
);
CREATE TABLE run_action (
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
CREATE TABLE action_attr (
   action_attr_id PRIMARY KEY,
   run_action INTEGER,
   "key" TEXT,
   value BLOB,
   FOREIGN KEY (run_action)
      REFERENCES run_action (run_action_id)
      ON DELETE CASCADE
);
CREATE TABLE error_string (
   error_id INTEGER PRIMARY KEY,
   string TEXT UNIQUE ON CONFLICT IGNORE
);
CREATE INDEX idx_input_time ON input (time);
CREATE INDEX repr_hash_idx ON repr (hash);
CREATE INDEX idx_error_string ON error_string (string);
```
