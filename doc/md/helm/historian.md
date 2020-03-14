# Historian


This module is responsible for REPL history.


Eventually this will include persisting and restoring from a SQLite database,
fuzzy searching, and variable cacheing.


Currently does the basic job of retaining history and not letting subsequent
edits munge it.


Next step: now that we clone a new txtbuf each time, we have an immutable
record.  We should store the line as a string, to facilitate fuzzy matching.


```lua
local uv      = require "luv"
local sql     = assert(sql, "sql must be in bridge _G")

local Txtbuf  = require "helm/txtbuf"
local Rainbuf = require "helm/rainbuf"
local c       = import("singletons/color", "color")
local repr    = require "helm/repr"

local concat, insert = assert(table.concat), assert(table.insert)
local reverse = require "core/table" . reverse
local meta = require "core/meta" . meta

local Set = require "set:set"
```
```lua
local File = require "fs:fs/file"
local Dir  = require "fs:fs/directory"
```
```lua
local Historian = meta {}
Historian.HISTORY_LIMIT = 2000
```
## Persistence

This defines the persistence model for bridge.

### SQLite battery

-  #Todo write a migration to convert timestamps to use this format:


   -  strftime('%Y-%m-%dT%H:%M:%f', 'now'))


      This replaces CURRENT_TIMESTAMP in the DEFAULT clause.


-  Then start using that instead, to get millisecond resolution.
   Sorting by line_id is better anyway, but we should get as much
   resolution out of the machine as we can.


-  #Todo write a migration to fix some of these silly table names:
   -  The repl table is mostly a line, and the result table is a repr,
      these could and should just be a line table with line.line and a
      result table with result.result.


#### Create tables

The schema with the highest version number is the one which is current for
that table.  The table will of course not have the ``_n`` suffix in the
database.  The number is that of the migration where the table was recreated.


Other than that, SQLite lets you add columns and rename tables.


When this is done, it will be noted.

```lua
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
```
#### Insertions

```lua
local insert_line = [[
INSERT INTO repl (project, line) VALUES (:project, :line);
]]

local insert_result = [[
INSERT INTO result (line_id, repr) VALUES (:line_id, :repr);
]]

local insert_project = [[
INSERT INTO project (directory) VALUES (?);
]]
```
#### Selections

```lua
local get_recent = [[
SELECT CAST (line_id AS REAL), line FROM repl
   WHERE project = :project
   ORDER BY line_id DESC
   LIMIT :num_lines;
]]

local get_number_of_lines = [[
SELECT CAST (count(line) AS REAL) from repl
   WHERE project = ?
;
]]

local get_project = [[
SELECT project_id FROM project
   WHERE directory = %s;
]]

local get_results = [[
SELECT result.repr
FROM result
WHERE result.line_id = :line_id
ORDER BY result.result_id;
]]
```
### Migrations

  We follow a simple format for migrations, incrementing the ``user_version``
pragma by 1 for each alteration of the schema.


We write a single function, which receives the database conn, for each change,
such that we should be able to take a database at any schema and bring it up
to the standard needed for this version of ``helm``.


We store these migrations in an array, such that ``migration[i]`` creates
``user_version`` ``i``.


We skip ``1`` because a pragma equal to 1 is translated to the boolean ``true``.


Migrations return ``true``, in case we find a migration that needs a check to
pass.  Unless that happens, we won't bother to check the return value.

```lua
local HELM_DB_VERSION = 3

local migrations = {function() return true end}
```
#### Version 2: Creates tables.

```lua
local function migration_2(conn)
   conn:exec(create_project_table)
   conn:exec(create_result_table)
   conn:exec(create_repl_table)
   conn:exec(create_session_table)
   return true
end

insert(migrations, migration_2)
```
#### Version 3: Millisecond-resolution timestamps.

  We want to accomplish two things here: change the format of all existing
timestamps, and change the default to have millisecond resolution and use
"T" instead of " " as the separator.


SQLite being what it is, the latter requires us to copy everything to a new
table.  This must be done for the ``project`` and ``repl`` tables.

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
### Migration shim

  Having the database in a hidden file is a holdover from when it was living
in ``~``.  It's a bad idea, hidden files interact badly with the Trash, it makes
it pointlessly difficult to check for a WAL file, and so on.


We have enough users (like, five I think) that I'm going to add a shim to
perform a migration to a new ``$BRIDGE_HOME/helm/`` directory.  Inside that
directory, the new name of ``.helm`` will be ``helm.sqlite``.

```lua
-- make the /helm directory
-- use sh to avoid a permissions issue with stale versions of fs
if not Dir(_Bridge.bridge_home .. "/helm"):exists() then
   local sh = require "orb:util/sh"
   sh("mkdir", "-p", _Bridge.bridge_home .. "/helm")
end

local old_helm = File (_Bridge.bridge_home .. "/.helm")
if old_helm:exists() then
   -- move it
   if File(_Bridge.bridge_home .. "/.helm-wal"):exists() then
      print "please shut down all helm instances before running migration"
      os.exit()
   end
   if File(_Bridge.bridge_home .. "/helm/helm.sqlite"):exists() then
      print "two databases in $BRIDGE_HOME: .helm and helm/helm.sqlite"
      print "probably, the migration has already been performed,"
      print "but an old copy of helm was then used."
      print "please inspect the databases with sqlite3 and delete the one"
      print "you don't want to keep."
      os.exit()
   end
   local sh = require "orb:util/sh"
   sh("mv " .. tostring(old_helm) .. " "
      .. _Bridge.bridge_home .. "/helm/helm.sqlite")
end
```

Fingers crossed... I'm definitely backing my database up before I run this!


```lua
Historian.helm_db = _Bridge.bridge_home .. "/helm/helm.sqlite"

Historian.project = uv.cwd()

local function has(table, name)
   for _,v in ipairs(table) do
      if name == v then
         return true
      end
   end
   return false
end
```
### Historian:load()

Brings up the project history and result ids.


Most of the complexity serves to make a simple key/value relationship
between the regenerated txtbufs and their associated result history.


We want as much history as practical, because we search in it, but most of
the results never get used.

```lua
local bound, inbounds = import("core:core/math", "bound", "inbounds")
local assertfmt = import("core:core/string", "assertfmt")
local format = assert(string.format)


function Historian.load(historian)
   local conn = sql.open(historian.helm_db, "rwc")
   historian.conn = conn
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
      for i = user_version, HELM_DB_VERSION do
         migrations[i](conn)
      end
      conn.pragma.user_version(HELM_DB_VERSION)
   elseif user_version > HELM_DB_VERSION then
      error(format("Error: helm.sqlite is version %d, expected %d",
                   user_version, HELM_DB_VERSION))
      os.exit(HELM_DB_VERSION)
   end
   -- Retrieve project id
   local proj_val, proj_row = sql.pexec(conn,
                                  sql.format(get_project, historian.project),
                                  "i")
   if not proj_val then
      local ins_proj_stmt = conn:prepare(insert_project)
      ins_proj_stmt : bind(historian.project)
      proj_val, proj_row = ins_proj_stmt:step()
      -- retry
      proj_val, proj_row = sql.pexec(conn,
                              sql.format(get_project, historian.project),
                              "i")
      if not proj_val then
         error "Could not create project in .bridge"
      end
   end
   local project_id = proj_val[1][1]
   historian.project_id = project_id
   -- Create insert prepared statements
   historian.insert_line = conn:prepare(insert_line)
   historian.insert_result = conn:prepare(insert_result)
   -- Create result retrieval prepared statement
   historian.get_results = conn:prepare(get_results)
   -- Retrieve history
   local number_of_lines = conn:prepare(get_number_of_lines)
                             :bind(project_id):step()[1]
   if number_of_lines == 0 then
      return nil
   end
   number_of_lines = bound(number_of_lines, nil, historian.HISTORY_LIMIT)
   local pop_stmt = conn:prepare(get_recent)
                      : bindkv { project = project_id,
                                 num_lines = number_of_lines }
   historian.cursor = number_of_lines + 1
   historian.cursor_start = number_of_lines + 1
   historian.n = number_of_lines
   local counter = number_of_lines
   local idler
   local function load_one()
      local res = pop_stmt:step()
      if not res then
         if idler then idler:stop() end
         return nil
      end
      historian[counter] = Txtbuf(res[2])
      historian.line_ids[counter] = res[1]
      -- Results are loaded backwards because that's how they're accessed
      counter = counter - 1
   end
   -- add one line to ensure we have history on startup
   load_one()
   -- idle to populate the rest of the history
   idler = uv.new_idle()
   idler:start(load_one)
end
```
### Historian:restore_session(modeS, session)

If there is an open session, we want to replay it.


To do this, we need to borrow the modeselektor.

```lua

```
### Historian:persist(txtbuf, results)

Persists a line and results to store.


The hooks are in place to persist the results. I'm starting with a string
representation; the goal is to provide the sense of persistence across
sessions, and supplement that over time with better and better approximations.


To really nail it down will require semantic analysis and hence thorough
parsing.  General-purpose persistence tools belong in ``sqlayer``, which will
merge with our increasingly-modified ``sqlite`` bindings.


Medium-term goal is to hash any Lua object in a way that will resolve to a
common value for any identical semantics.

```lua
function Historian.persist(historian, txtbuf, results)
   local lb = tostring(txtbuf)
   local have_results = results
                        and type(results) == "table"
                        and results.n
   if lb == "" then
      -- A blank line can have no results and is uninteresting.
      return false
   end
   historian.conn:exec("SAVEPOINT save_persist")
   historian.insert_line:bindkv { project = historian.project_id,
                                       line    = lb }
   local err = historian.insert_line:step()
   if not err then
      historian.insert_line:clearbind():reset()
   else
      error(err)
   end
   local line_id = sql.lastRowId(historian.conn)
   insert(historian.line_ids, line_id)

   local persist_idler = uv.new_idle()
   local results_tostring, results_lineGens = {}, {}
   if have_results then
      for i = 1, results.n do
         results_lineGens[i] = repr.lineGenBW(results[i])
         results_tostring[i] = {}
      end
   end
   local i = 1
   historian.idlers:insert(persist_idler)
   persist_idler:start(function()
      while have_results and i <= results.n do
         local success, line = pcall(results_lineGens[i])
         if success and line then
            insert(results_tostring[i], line)
         else
            results_tostring[i] = concat(results_tostring[i], "\n")
            i = i + 1
            if not success then
               error(line)
            end
         end
         return nil
      end
      -- now persist
      if have_results then
         for i = 1, results.n do
            historian.insert_result:bindkv { line_id = line_id,
                                             repr = results_tostring[i] }
            err = historian.insert_result:step()
            if not err then
               historian.insert_result:clearbind():reset()
            else
               error(err)
            end
         end
      end
      historian.conn:exec("RELEASE save_persist")
      persist_idler:stop()
      assert(historian.idlers:remove(persist_idler) == true)
   end)
   return true
end
```
## Historian:search(frag)

This is a 'fuzzy search', that attempts to find a string containing the
letters of the fragment in order.


If it finds nothing, it switches the last two letters and tries again. This
is an affordance for incremental searches, it's easy to make this mistake and
harmless to suggest the alternative.


Returns a ``collection``. The array portion of a collection is any line
which matches the search. The other fields are:


- #fields
  -  best :  Whether this is a best-fit collection, that is, one with all
             codepoints in order.


  -  frag :  The fragment, used to highlight the collection.  Is transposed
             in a next-best search.


  -  lit_frag :  The literal fragment passed as the ``frag`` parameter.  Used to
                 compare to the last search.


  -  cursors :  This is an array, each value is the cursor position of
                the corresponding line in the history.


```lua
local SelectionList = require "helm/selection_list"
local fuzz_patt = require "helm:helm/fuzz_patt"

function Historian.search(historian, frag)
   if historian.last_collection
      and historian.last_collection[1].lit_frag == frag then
      -- don't repeat a search
      return historian.last_collection
   end
   if frag == "" then
      return ""
   end
   local result = SelectionList()
   result.cursors = {}
   result.frag = frag
   result.lit_frag = frag
   result.best = true
   result.show_shortcuts = true
   local function try_search()
      local patt = fuzz_patt(result.frag)
      local dup = {}
      for i = historian.n, 1, -1 do
         local item_str = tostring(historian[i])
         if not dup[item_str] and patt:match(item_str) then
            dup[item_str] = true
            insert(result, item_str)
            insert(result.cursors, i)
         end
      end
   end
   try_search()
   if #result == 0 then
      result.best = false
      result.frag = frag:sub(1, -3) .. frag:sub(-1, -1) .. frag:sub(-2, -2)
      try_search()
   end
   result.selected_index = 1
   historian.last_collection = Rainbuf {[1] = result, n = 1, live = true}
   historian.last_collection.made_in = "historian.search"
   return historian.last_collection
end
```
#### _resultsFrom(historian, line_id)

Retrieve a set of results reprs from the database, given a line_id.

```lua
local lines = import("core/string", "lines")
local function _db_result__repr(result)
   local result_iter = lines(result[1])
   return function()
      local line = result_iter()
      if line then
         return c.greyscale(line)
      else
         return nil
      end
   end
end

local _db_result_M = meta {}
_db_result_M.__repr = _db_result__repr


local function _resultsFrom(historian, cursor)
   if historian.result_buffer[cursor] then
      return historian.result_buffer[cursor]
   end
   local line_id = historian.line_ids[cursor]
   local stmt = historian.get_results
   stmt:bindkv {line_id = line_id}
   local results = stmt:resultset()
   if results then
      results = results[1]
      results.n = #results
      for i = 1, results.n do
         -- stick the result in a table to enable repr-ing
         results[i] = {results[i]}
         setmetatable(results[i], _db_result_M)
      end
   end
   historian.get_results:reset()
   -- may as well memoize the database call, while we're here
   historian.result_buffer[line_id] = results
   return results
end
```
## Historian:prev()

```lua

function Historian.prev(historian)
   historian.cursor = bound(historian.cursor - 1, 1)
   local txtbuf = historian[historian.cursor]
   if txtbuf then
      txtbuf = txtbuf:clone()
      txtbuf:startOfText()
      txtbuf:endOfLine()
      local result = _resultsFrom(historian, historian.cursor)
      return txtbuf, result
   else
      return Txtbuf(), nil
   end
end
```
### Historian:next()

Returns the next txtbuf in history, and a second flag to tell the
``modeselektor`` it might be time for a new one.


```lua
function Historian.next(historian)
   historian.cursor = bound(historian.cursor + 1, nil, historian.n + 1)
   local txtbuf = historian[historian.cursor]
   if txtbuf then
      txtbuf = txtbuf:clone()
      txtbuf:endOfText()
      local result = _resultsFrom(historian, historian.cursor)
      return txtbuf, result
   else
      return nil, nil
   end
end
```
### Historian:index(cursor)

Loads the history to an exact index. The index must be one that actually exists,
i.e. 1 <= index <= historian.n--historian.n + 1 is not allowed.

```lua
function Historian.index(historian, cursor)
   assert(inbounds(cursor, 1, historian.n))
   local txtbuf = historian[cursor]:clone()
   txtbuf:endOfText()
   local result = _resultsFrom(historian, cursor)
   historian.cursor = cursor
   return txtbuf, result
end
```
### Historian:append(txtbuf, results, success)

Appends a txtbuf to history and persists it.


Doesn't adjust the cursor.

```lua
function Historian.append(historian, txtbuf, results, success)
   if tostring(historian[historian.n]) == tostring(txtbuf)
      or tostring(txtbuf) == "" then
      -- don't bother
      return false
   end
   historian[historian.n + 1] = txtbuf
   historian.n = historian.n + 1
   if success then
      historian:persist(txtbuf, results)
   else
      historian:persist(txtbuf)
   end
   return true
end
```
```lua

local __result_buffer_M = meta {}
function __result_buffer_M.__repr()
   return c.alert "cowardly refusing to print result_buffer to avoid infinite appending"
end

local function new()
   local historian = meta(Historian)
   historian.line_ids = {}
   historian.cursor = 0
   historian.cursor_start = 0
   historian.n = 0
   historian:load()
   historian.result_buffer = setmetatable({}, __result_buffer_M)
   historian.idlers = Set()
   return historian
end
Historian.idEst = new
```
```lua
return new

```
