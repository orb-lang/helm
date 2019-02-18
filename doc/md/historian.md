# Historian


This module is responsible for REPL history.


Eventually this will include persisting and restoring from a SQLite database,
fuzzy searching, and variable cacheing.


Currently does the basic job of retaining history and not letting subsequent
edits munge it.


Next step: now that we clone a new txtbuf each time, we have an immutable
record.  We should store the line as a string, to facilitate fuzzy matching.


```lua
local Txtbuf  = require "txtbuf"
local Rainbuf = require "rainbuf"
local sql     = require "sqlayer"
local color   = require "color"
local L       = require "lpeg"
local repr    = require "repr"
local format  = assert (string.format)
local sub     = assert (string.sub)
local codepoints = assert(string.codepoints, "must have string.codepoints")
local reverse = assert (table.reverse)
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
time DATETIME DEFAULT CURRENT_TIMESTAMP );
]]

local create_repl_table = [[
CREATE TABLE IF NOT EXISTS repl (
line_id INTEGER PRIMARY KEY AUTOINCREMENT,
project INTEGER,
line TEXT,
time DATETIME DEFAULT CURRENT_TIMESTAMP,
FOREIGN KEY (project)
   REFERENCES project (project_id)
   ON DELETE CASCADE );
]]

local create_result_table = [[
CREATE TABLE IF NOT EXISTS result (
result_id INTEGER PRIMARY KEY AUTOINCREMENT,
line_id INTEGER,
repr text NOT NULL,
value blob,
FOREIGN KEY (line_id)
   REFERENCES repl (line_id)
   ON DELETE CASCADE );
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

Historian.project = io.popen("pwd", "r"):read("*a"):sub(1, -2)

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
      ins_proj_stmt:bindkv {dir = historian.project}
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
local concat = table.concat
function Historian.persist(historian, txtbuf, results)
   local lb = tostring(txtbuf)
   if lb ~= "" then
      historian.insert_line:bindkv { project = historian.project_id,
                                          line    = lb }
      local err = historian.insert_line:step()
      if not err then
         historian.insert_line:clearbind():reset()
      else
         error(err)
      end
      local line_id = sql.lastRowId(historian.conn)
      table.insert(historian.line_ids, line_id)
      if results and type(results) == "table" then
         for i = 1, results.n do
            -- insert result repr
            local res = results[i]
            historian.insert_result:bindkv { line_id = line_id,
                                                  repr = repr.ts(res) }
            err = historian.insert_result:step()
            if not err then
               historian.insert_result:clearbind():reset()
            end
         end
      end

   return true
   else
      -- A blank line can have no results and is uninteresting.
      return false
   end
   --]]
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

local function _highlight(line, frag, c, best)
   local hl = {}
   local og_line = line -- debugging
   while #frag > 0 do
      local char
      char, frag = frag:sub(1,1), frag:sub(2)
      local at = line:find(litpat(char))
      if not at then
         error ("can't find " .. char .. " in: " .. line)
      end
      local color
      -- highlight the last two differently if this is a 'second best'
      -- search
      if not best and #frag <= 1 then
         color = c.alert
      else
         color = c.search_hl
      end
      hl[#hl + 1] = c.base(line:sub(1, at -1))
      hl[#hl + 1] = color(char)
      line = line:sub(at + 1)
   end
   hl[#hl + 1] = c.base(line)
   return concat(hl):gsub("\n", c.stresc("\\n"))
end


local function _collect_repr(collection, c)
   if #collection == 0 then
      return c.alert "No results found"
   end
   local phrase = ""
   for i,v in ipairs(collection) do
      local alt_seq = "    "
      if i < 10 then
         alt_seq = a.bold("M-" .. tostring(i) .. " ")
      end
      local next_line = alt_seq
                        .. _highlight(v, collection.frag, c, collection.best)
                        .. "\n"
      if i == collection.hl then
         next_line = c.highlight(next_line)
      end
      phrase = phrase .. next_line
   end

   return phrase
end

local collect_M = {__repr = _collect_repr}
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
      and historian.last_collection.lit_frag == frag then
      -- don't repeat a search
      return historian.last_collection
   end
   local collection = setmeta({}, collect_M)
   collection.frag = frag
   collection.lit_frag = frag
   if frag == "" then
      return collection, false
   end
   local cursors = {}
   local best = true
   local patt = fuzz_patt(frag)
   for i = #historian, 1, -1 do
      local score = match(patt, tostring(historian[i]))
      if score then
         collection[#collection + 1] = tostring(historian[i])
         cursors[#cursors + 1] = i
      end
   end
   if #collection == 0 then
      -- try the transpose
      best = false
      local slip = sub(frag, 1, -3) .. sub(frag, -1, -1) .. sub(frag, -2, -2)
      collection.frag = slip
      patt = fuzz_patt(slip)
      for i = #historian, 1, -1 do
         local score = match(patt, tostring(historian[i]))
         if score then
            collection[#collection + 1] = tostring(historian[i])
            cursors[#cursors + 1] = i
         end
      end
   end
   collection.best = best
   collection.cursors = cursors
   collection.hl = 1
   historian.last_collection = collection
   return collection, best
end
```
#### _resultsFrom(historian, line_id)

Retrieve a set of results reprs from the database, given a line_id.

```lua
local function _resultsFrom(historian, line_id)
   local stmt = historian.get_results
   stmt:bindkv {line_id = line_id}
   local results = stmt:resultset()
   if results then
      results = results[1]
      results.n = #results
      results.frozen = true
   end
   historian.get_results:clearbind():reset()
   return results
end
```
## Historian:prev()

```lua
function Historian.prev(historian)
   if historian.cursor == 0 or #historian == 0 then
      return Txtbuf()
   end
   local Δ = historian.cursor > 1 and historian.cursor - 1 or historian.cursor
   local txtbuf = historian[Δ]
   txtbuf.cur_row = 1
   local result = _resultsFrom(historian, historian.line_ids[Δ])
   --local result = historian.results[txtbuf]
   historian.cursor = Δ
   txtbuf.cursor = #txtbuf.lines[txtbuf.cur_row] + 1
   return txtbuf:clone(), result
end
```
### Historian:next()

Returns the next txtbuf in history, and a second flag to tell the
``modeselektor`` it might be time for a new one.


```lua
function Historian.next(historian)
   local Δ = historian.cursor < #historian
             and historian.cursor + 1
             or  historian.cursor
   local fwd = historian.cursor >= #historian
   if historian.cursor == 0 or #historian == 0 then
      return Txtbuf()
   end
   local txtbuf = historian[Δ]
   if not txtbuf then
      return Txtbuf(), nil, true
   end
   txtbuf.cur_row = #txtbuf.lines
   local result = _resultsFrom(historian, historian.line_ids[Δ])
   historian.cursor = Δ
   txtbuf.cursor = #txtbuf.lines[txtbuf.cur_row] + 1
   if fwd and #txtbuf.lines > 0 then
      historian.cursor = #historian + 1
      return txtbuf:clone(), nil, true
   else
      return txtbuf:clone(), result, false
   end
end
```
### Historian:index(cursor)

Loads the history to an exact index.

```lua
function Historian.index(historian, cursor)
   if (not cursor) or cursor < 0 or cursor > #historian + 1 then
      return Txtbuf()
   end
   local txtbuf = historian[cursor]
   local result = _resultsFrom(historian, historian.line_ids[cursor])
   txtbuf = txtbuf:clone()
   historian.cursor = cursor
   txtbuf.cur_row = #txtbuf.lines
   txtbuf.cursor = #txtbuf.lines[txtbuf.cur_row] + 1
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
local function new()
   local historian = meta(Historian)
   historian:load()
   return historian
end
Historian.idEst = new
```
```lua
return new
```
