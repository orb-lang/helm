# Historian


This module is responsible for REPL history.


Eventually this will include persisting and restoring from a SQLite database,
fuzzy searching, and variable cacheing.


Currently does the basic job of retaining history and not letting subsequent
edits munge it.


Next step: now that we clone a new txtbuf each time, we have an immutable
record.  We should store the line as a string, to facilitate fuzzy matching.


```lua
local L       = require "lpeg"
local uv      = require "luv"
local sql     = assert(sql, "sql must be in bridge _G")

local Txtbuf  = require "helm/txtbuf"
local Rainbuf = require "helm/rainbuf"
local c       = (require "singletons/color").color
local repr    = require "helm/repr"

local format, sub, codepoints = assert(string.format),
                                assert(string.sub),
                                assert(string.codepoints)
local concat, reverse         = assert(table.concat), assert(table.reverse)
assert(meta)
```
```lua
local Historian = meta {}
```
## Persistence

This defines the persistence model for bridge.

### SQLite battery

```lua
Historian.HISTORY_LIMIT = 2000

local create_project_table = [[
CREATE TABLE IF NOT EXISTS project (
   project_id INTEGER PRIMARY KEY AUTOINCREMENT,
   directory TEXT UNIQUE,
   time DATETIME DEFAULT CURRENT_TIMESTAMP
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

local insert_line = [[
INSERT INTO repl (project, line) VALUES (:project, :line);
]]

local insert_result = [[
INSERT INTO result (line_id, repr) VALUES (:line_id, :repr);
]]

local insert_project = [[
INSERT INTO project (directory) VALUES (:dir);
]]

local get_tables = [[
SELECT name FROM sqlite_master WHERE type='table';
]]

local get_recent = [[
SELECT CAST (line_id AS REAL), line FROM repl
   WHERE project = %d
   ORDER BY time
   DESC LIMIT %d;
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

local home_dir = io.popen("echo $HOME", "r"):read("*a"):sub(1, -2)

local bridge_home = io.popen("echo $BRIDGE_HOME", "r"):read("*a"):sub(1, -2)
Historian.bridge_home = bridge_home ~= "" and bridge_home
                        or home_dir .. "/.bridge"

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

Brings up the project history and results, and (eventually) user config.


Most of the complexity serves to make a simple key/value relationship
between the regenerated txtbufs and their associated result history.

#todo There's actually no reason to load all the results, as we don't use the
the results never get used.

```lua
function Historian.load(historian)
   local conn = sql.open(historian.bridge_home)
   historian.conn = conn
   -- Set up bridge tables
   conn.pragma.foreign_keys(true)
   conn:exec(create_project_table)
   conn:exec(create_result_table)
   conn:exec(create_repl_table)
   conn:exec(create_session_table)
   -- Retrive project id
   local proj_val, proj_row = sql.pexec(conn,
                                  sql.format(get_project, historian.project),
                                  "i")
   if not proj_val then
      local ins_proj_stmt = conn:prepare(insert_project)
      ins_proj_stmt : bindkv { dir = historian.project }
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
   local pop_str = sql.format(get_recent, project_id,
                        historian.HISTORY_LIMIT)
   local repl_val  = sql.pexec(conn, pop_str, "i")
   if repl_val then
      local lines = reverse(repl_val[2])
      local line_ids = reverse(repl_val[1])
      historian.line_ids = line_ids
      local repl_map = {}
      for i, v in ipairs(lines) do
         local buf = Txtbuf(v)
         historian[i] = buf
         repl_map[line_ids[i]] = buf
      end
      historian.cursor = #historian
   else
      historian.results = {}
      historian.line_ids = {}
      historian.cursor = 0
   end
end
```
### Historian:restore_session(modeS, session)

If there is an open session, we want to replay it.


To do this, we need to borrow the modeselektor.

```lua

```
### Historian:persist(txtbuf)

Persists a line and results to store.


The hooks are in place to persist the results. I'm starting with a string
representation; the goal is to provide the sense of persistence across
sessions, and supplement that over time with better and better approximations.

#todo storing the colorized results is lazy and they should be greyed-out in
parsing.  General-purpose persistence tools belong in ``sqlayer``, which will
merge with our increasingly-modified ``sqlite`` bindings.


Medium-term goal is to hash any Lua object in a way that will resolve to a
common value for any identical semantics.

```lua
local insert = assert(table.insert)

function Historian.persist(historian, txtbuf, results)
   local lb = tostring(txtbuf)
   local have_results = results
                        and type(results) == "table"
                        and results.n
   if lb == "" then
      -- A blank line can have no results and is uninteresting.
      return false
   end
   local persist_idler = uv.new_idle()
   local results_tostring, results_lineGens = {}, {}
   if have_results then
      for i = 1, results.n do
         results_lineGens[i] = repr.lineGenBW(results[i])
         assert(type(results_lineGens[i]) == 'function')
         results_tostring[i] = {}
      end
   end
   local i = 1
   persist_idler:start(function()
      while have_results and i <= results.n do
         local line = results_lineGens[i]()
         if line then
            insert(results_tostring[i], line)
            return nil
         else
            results_tostring[i] = concat(results_tostring[i], "\n")
            i = i + 1
            return nil
         end
      end
      -- now persist
      historian.conn:exec "BEGIN TRANSACTION;"
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
      historian.conn:exec "END TRANSACTION;"
      persist_idler:stop()
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


### fuzz_patt

Here we incrementally build up a single ``lpeg`` pattern which will recognize
our desired lines.


``(P(1) - P(frag[n]))^0`` matches anything that isn't the next fragment,
including ``""``.  We then require this to be followed by the next fragment,
and so on.

```lua
local P, match = L.P, L.match

local function fuzz_patt(frag)
   frag = type(frag) == "string" and codepoints(frag) or frag
   local patt =  (P(1) - P(frag[1]))^0
   for i = 1 , #frag - 1 do
      local v = frag[i]
      patt = patt * (P(v) * (P(1) - P(frag[i + 1]))^0)
   end
   patt = patt * P(frag[#frag])
   return patt
end
```
### __repr for collection

We use a pseudo-metamethod called ``__repr`` to specify custom table
representations.  These take the table as the first value and receive the
local color palette for consistency.


In this case we want to highlight the letters of the fragment, which we
attach to the collection.

```lua
local concat, litpat = assert(table.concat), assert(string.litpat)
local gsub = assert(string.gsub)
local function _highlight(line, frag, best, c)
   local hl = {}
   while #frag > 0 do
      local char
      char, frag = frag:sub(1, 1), frag:sub(2)
      local at = line:find(litpat(char))
      if not at then
         break
      end
      local Color
      -- highlight the last two differently if this is a 'second best'
      -- search
      if not best and #frag <= 1 then
         Color = c.alert
      else
         Color = c.search_hl
      end
      hl[#hl + 1] = c.base(line:sub(1, at - 1))
      hl[#hl + 1] = Color(char)
      line = line:sub(at + 1)
   end
   hl[#hl + 1] = c.base(line)
   return concat(hl):gsub("\n", c.stresc .. "\\n" .. c.base)
end

local function _collect_repr(collection, phrase, c)
   assert(c, "must provide a color table")
   local i = 1
   local first = true
   return function()
      if #collection == 0 then
         if first then
            first = false
            return c.alert "No results found"
         else
            return nil
         end
      end
      local line = collection[i]
      if line == nil then return nil end
      local len = #line
      local alt_seq = "    "
      if i < 10 then
         alt_seq = c.bold("M-" .. tostring(i) .. " ")
      end
      len = len + 4
      if len > phrase:remains() then
         line = line:sub(1, phrase:remains() - 5) .. c.alert "…"
         len = phrase.width - (phrase.width - phrase:remains() - 4)
      end
      local next_line = alt_seq
                     .. _highlight(line, collection.frag, collection.best, c)
      if i == collection.hl then
         next_line = c.highlight(next_line)
      end
      i = i + 1
      return next_line, len
   end
end

local collect_M = {__repr = _collect_repr}
collect_M.__index = collect_M
```
## Historian:search(frag)

This is an incremental 'fuzzy' search, returning a ``collection``.


The array portion of a collection is any line which matches the search.


The other fields are:


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
function Historian.search(historian, frag)
   if historian.last_collection
      and historian.last_collection[1].lit_frag == frag then
      -- don't repeat a search
      return historian.last_collection
   end
   local matches = {}
   local lit_frag = frag
   if frag == "" then
      return Rainbuf {[1] = matches, n = 1}, false
   end
   local slip = nil
   local cursors = {}
   local best = true
   local patt = fuzz_patt(frag)
   for i = #historian, 1, -1 do
      local score = match(patt, tostring(historian[i]))
      if score then
         matches[#matches + 1] = tostring(historian[i])
         cursors[#cursors + 1] = i
      end
   end
   if #matches == 0 then
      -- try the transpose
      best = false
      slip = sub(frag, 1, -3) .. sub(frag, -1, -1) .. sub(frag, -2, -2)
      patt = fuzz_patt(slip)
      for i = #historian, 1, -1 do
         local score = match(patt, tostring(historian[i]))
         if score then
            matches[#matches + 1] = tostring(historian[i])
            cursors[#cursors + 1] = i
         end
      end
   end
   -- deduplicate
   local collection = setmeta({}, collect_M)
   local collect_cursors = {}
   local dup = {}
   for i, line in ipairs(matches) do
      if not dup[line] then
         dup[line] = true
         collection[#collection + 1] = line
         collect_cursors[#collect_cursors + 1] = cursors[i]
      end
   end

   collection.frag = slip or frag
   collection.lit_frag = lit_frag
   collection.best = best
   collection.cursors = collect_cursors
   collection.hl = 1
   historian.last_collection = Rainbuf {[1] = collection, n = 1, live = true}
   historian.last_collection.made_in = "historian.search"
   return historian.last_collection, best
end
```
#### _resultsFrom(historian, line_id)

Retrieve a set of results reprs from the database, given a line_id.

```lua
local lines = assert(string.lines)
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
         setmeta(results[i], _db_result_M)
      end
   end
   historian.get_results:clearbind():reset()
   -- may as well memoize the database call, while we're here
   historian.result_buffer[line_id] = results
   return results
end
```
## Historian:prev()

```lua
local bound = assert(math.bound)

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
   historian.cursor = bound(historian.cursor + 1, nil, #historian + 1)
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
i.e. 1 <= index <= #historian--#historian + 1 is not allowed.

```lua
local inbounds = assert(math.inbounds)

function Historian.index(historian, cursor)
   assert(inbounds(cursor, 1, #historian))
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
   if tostring(historian[#historian]) == tostring(txtbuf)
      or tostring(txtbuf) == "" then
      -- don't bother
      return false
   end
   historian[#historian + 1] = txtbuf
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
   historian:load()
   historian.result_buffer = setmetatable({}, __result_buffer_M)
   return historian
end
Historian.idEst = new
```
```lua
return new
```
