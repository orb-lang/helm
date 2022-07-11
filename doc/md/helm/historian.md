# Historian


This module is responsible for REPL history\.

Historian loads old records of lines and results from a SQLite database, as
well as persisting new ones to the same store\.

It is also responsible for fuzzy searching across the last `HISTORY_LIMIT` of
records\.


#### imports

```lua
local uv      = require "luv"

local bridge = require "bridge"

local s = require "status:status" ()

local Session = require "helm:session"
local persist_tabulate = require "repr:persist-tabulate"
local helm_db = require "helm:helm-db"

local insert = assert(table.insert)

local Deque = require "deque:deque"
```


### Historian metatable

```lua
local Historian = meta {}
Historian.HISTORY_LIMIT = 2000
Historian.helm_db_home = helm_db.helm_db_home
Historian.project = uv.cwd()
```

### Historian:createPreparedStatements\(helm\_db\)

```lua
function Historian.createPreparedStatements(historian, helm_db_home)
   if helm_db_home then
      historian.helm_db_home = helm_db_home
   end
   local stmts = helm_db.historian(historian.helm_db_home)
   historian.stmts = stmts
   historian.insert_line = stmts.insert_line
   historian.insert_repr = stmts.insert_repr
   historian.insert_result_hash = stmts.insert_result_hash
   historian.get_results = stmts.get_results
end
```

### sql\_insert\_errcheck\(stmt\)

Execute the \(already\-bound\) prepared statement, `stmt`, which is assumed to be
an insert such that it returns a value only if it fails\. We convert that into
a Lua error, and in any case reset the statement so it can be reused\.

```lua
local function sql_insert_errcheck(stmt)
   local err = stmt:step()
   stmt:clearbind():reset()
   if err then
      error(err)
   end
end
```

\#todo

### Historian:load\(\)

Brings up the project history and result ids\.

Most of the complexity serves to make a simple key/value relationship
between the lines and their associated result history\.

We want as much history as practical, because we search in it, but most of
the results never get used\.

As much of the work as possible is offloaded to a uv idler process\.

```lua
local math = core.math
local clamp, inbounds = assert(math.clamp), assert(math.inbounds)

function Historian.load(historian)
   local stmts = historian.stmts
   -- Retrieve project id
   local proj_val, proj_row = stmts.get_project
                                      : bind(historian.project)
                                      : resultset 'i'
   if not proj_val then
      proj_val, proj_row = stmts.insert_project
                             : bind(historian.project)
                             : step()
      -- retry
      proj_val, proj_row = stmts.get_project
                                      : bind(historian.project)
                                      : resultset 'i'
      if not proj_val then
         error "Could not create project in .bridge"
      end
   end
   local project_id = proj_val[1][1]
   historian.project_id = project_id

   -- start the latest run
   stmts.insert_run_start :bind(project_id) :step()
   historian.run = { run_id = stmts.lastRowId(), actions = {} }

   -- Retrieve history
   local number_of_lines = stmts.get_number_of_lines
                             :bind(project_id):step()[1]
   if number_of_lines == 0 then
      return nil
   end
   number_of_lines = clamp(number_of_lines, nil, historian.HISTORY_LIMIT)
   historian.lines_available = number_of_lines
   local pop_stmt = stmts.get_recent
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
      historian[counter] = res[2]
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


### Historian:loadPreviousRun\(\)

Loads the previous run, ready to review or re\-evaluate, in a format similar to
a Session\. Stores it as historian\.previous\_run, this will probably change\.

\#todo

```lua
function Historian.loadPreviousRun(historian)
   local prev_run_id = historian.stmts.get_latest_finished_run
                                       :bind(historian.project_id)
                                       :value()
   local run = {}
   for _, line_id, line in historian.stmts.get_lines_of_run:bind(prev_run_id):cols() do
      insert(run, {
         status = "keep",
         line = line,
         line_id = line_id,
         old_result = historian:resultsFor(line_id)
      })
   end
   historian.previous_run = run
end
```


### Historian:loadRecentLines\(num\_lines\)

Loads `num_lines` recent lines from the history and returns them as a `deque`\.

```lua
function Historian.loadRecentLines(historian, num_lines)
   local deque = require "deque:deque" ()
   -- we could duplicate this information off the historian array, if we
   -- had the patience to wait around for it to populate.
   --
   -- We probably should do it that way, actually, but there's too much
   -- handwaving about how runs interact with history already, and this
   -- works, as blocking code tends to, with minimum fuss.
   if num_lines > historian.lines_retrieved then
      s:warn("Requested %d lines to rerun, only %d lines available")
      num_lines = historian.lines_retrieved
   end
   local get_lines = historian.stmts.get_recent
                : bindkv { project = historian.project_id,
                           num_lines = num_lines }
   for _, __, line in get_lines:cols() do
      deque:push(line)
   end
   deque:reverse()
   return deque
end
```


### Historian:loadOrCreateSession\(session\_title\)

Creates a session with the given title, retrieving its id from the database if
it already exists\.

\#todo
easiest way to make this work but this is a rather trivial function\.\.\.

```lua
function Historian.loadOrCreateSession(historian, session_title)
   historian.session = Session(historian.helm_db_home,
                        historian.project_id,
                        session_title)
end
```


### Historian:resultsFor\(line\_id\)

Returns results for the line identified by `line_id`, retrieving them from the
database if needed and preferring "live" results over persisted ones when
available\.

```lua
local db_result_M = assert(persist_tabulate.db_result_M)

local function _wrapResults(results_tostring)
   local wrapped = { n = #results_tostring }
   for i = 1, wrapped.n do
      -- stick the actual string in a table with an __repr that reconstitutes
      -- the object tree from tokens
      wrapped[i] = setmetatable({results_tostring[i]}, db_result_M)
   end
   return wrapped
end

function Historian.resultsFor(historian, line_id)
   if historian.result_buffer[line_id] then
      return historian.result_buffer[line_id]
   end
   local stmt = historian.get_results
   stmt:bindkv {line_id = line_id}
   local results = stmt :resultset 'i'
   if results then
      results = _wrapResults(results[1])
   end
   stmt:reset()
   -- may as well memoize the database call, while we're here
   historian.result_buffer[line_id] = results
   return results
end
```


### Historian:persist\(line, results\)

Persists a line and results to store\.

```lua
local tabulate_some = assert(persist_tabulate.tabulate_some)
local sha = assert(require "util:sha" . shorthash)
local blob = assert(assert(sql, "sql must be in bridge _G").blob)
function Historian.persist(historian, line, results)
   if type(results) ~= "table" or results.n == 0 then
      results = nil
   end
   if line == "" then
      -- A blank line can have no results and is uninteresting.
      return false
   end

   -- Persist the line of input itself
   sql_insert_errcheck(
      historian.insert_line:bindkv { project = historian.project_id,
                                     line    = blob(line) })
   local line_id = historian.stmts.lastRowId()
   historian.result_buffer[line_id] = results

   -- Then the run action indicating it was just evaluated
   local run_action = { run_id  = historian.run.run_id,
                        ordinal = #historian.run.actions + 1,
                        input   = line_id }
   insert(historian.run.actions, run_action)
   sql_insert_errcheck(historian.stmts.insert_run_input:bindkv(run_action))

   -- If there are no results, nothing more to persist,
   -- release our savepoint and don't bother starting the idler
   if not results then
      return line_id
   end

   local queue = historian.result_queue
   local persist_cb = tabulate_some(results)
   historian.idler = historian.idler or uv.new_idle()
   local empty = #queue == 0
   queue:push(pack(persist_cb, line_id, results.n))
   if empty then
      historian.idler:start(function()
         local cb, line_id, n = unpack(queue:peek())
         local done, results_tostring = cb()
         if not done then return nil end
         queue:pop()
         -- now persist
         for i = 1, n do
            local hash = sha(results_tostring[i])
            sql_insert_errcheck(historian.insert_repr:bind(hash, results_tostring[i]))
            sql_insert_errcheck(historian.insert_result_hash:bind(line_id, hash))
         end
         -- inform the Session that persisted results are available
         -- #todo this *so badly* needs to be an Action
         -- Should probably also be called 'resultsPersisted' since the
         -- live results are available immediately. We might also want to
         -- cache the stringified/persisted results alongside the live ones
         if historian.session then
            historian.session:resultsAvailable(line_id,
               _wrapResults(results_tostring))
         end
         if #queue == 0 then
            historian.idler:stop()
         end
      end)
   end
   return line_id
end
```


### Historian:idling\(\)

Replies `true` if we have a running idler

```lua
function Historian.idling(hist)
   if #hist.result_queue > 0 then
      return true
   else
      return false
   end
end
```


### Historian:append\(line, results, success\)

As :persist\(\), but also appends to the history and the current session\.

Doesn't adjust the cursor, but does store the results in the result\_buffer\.

```lua
function Historian.append(historian, line, results, success)
   if line == "" then
      -- don't bother
      return false
   end
   if not success then results = nil end
   local line_id = historian:persist(line, results)
   historian.n = historian.n + 1
   historian[historian.n] = line
   historian.line_ids[historian.n] = line_id
   -- #todo this should be an Action--actually we should be in a handler for
   -- one action (e.g. 'evalCompleted') and issue another (e.g. 'lineStored')
   if historian.session then
      historian.session:append(line_id, line, results)
   end
   return true
end
```


### Historian:appendNow\(line, results, success\)

A blocking append, to be used in rerunning sessions \(and perhaps in general\)\.

```lua
local tabulate = persist_tabulate.tabulate

function Historian.appendNow(historian, line, results, success)
   if line == "" then
      -- don't bother
      return false
   end
   if (not success) or results.n == 0 then
      -- we /should/ handle errors here
      results = nil
   end

   -- Persist the line of input itself
   sql_insert_errcheck(
      historian.insert_line:bindkv { project = historian.project_id,
                                     line    = blob(line) })
   local line_id = historian.stmts.lastRowId()
   historian.result_buffer[line_id] = results

   -- Then the run action indicating it was just evaluated
   local run_action = { run_id  = historian.run.run_id,
                        ordinal = #historian.run.actions + 1,
                        input   = line_id }
   insert(historian.run.actions, run_action)
   sql_insert_errcheck(historian.stmts.insert_run_input:bindkv(run_action))

   -- If there are no results, nothing more to persist,
   -- release our savepoint and don't bother starting the idler
   if not results then
      return line_id
   end

   local results_tostring = tabulate(results)
   for i = 1, results.n do
      local hash = sha(results_tostring[i])
      sql_insert_errcheck(historian.insert_repr:bind(hash, results_tostring[i]))
      sql_insert_errcheck(historian.insert_result_hash:bind(line_id, hash))
   end
   -- inform the Session that persisted results are available
   -- #todo this *so badly* needs to be an Action
   -- Should probably also be called 'resultsPersisted' since the
   -- live results are available immediately. We might also want to
   -- cache the stringified/persisted results alongside the live ones
   if historian.session then
      historian.session:resultsAvailable(line_id,
         _wrapResults(results_tostring))
   end

   return line_id
end
```


## Historian:search\(frag\)

This is a 'fuzzy search', that attempts to find a string containing the
letters of the fragment in order\.

If it finds nothing, it switches the last two letters and tries again\. This
is an affordance for incremental searches, it's easy to make this mistake and
harmless to suggest the alternative\.

Returns a `collection`\. The array portion of a collection is any line
which matches the search\. The other fields are:


- \#fields
  -  best :  Whether this is a best\-fit collection, that is, one with all
      codepoints in order\.

  -  frag :  The fragment, used to highlight the collection\.  Is transposed
      in a next\-best search\.

  -  lit\_frag :  The literal fragment passed as the `frag` parameter\.  Used to
      compare to the last search\.

  -  cursors :  This is an array, each value is the cursor position of
      the corresponding line in the history\.


```lua
local SelectionList = require "helm/selection_list"
local fuzz_patt = require "helm:helm/fuzz_patt"

function Historian.search(historian, frag)
   if frag == "" then
      return nil
   end
   local result = SelectionList(frag, { show_shortcuts = true, cursors = {}})
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
   return result
end
```


## History navigation


### \_setCursor\(cursor\)

Sets the cursor and returns the line and results for that index\. Unlike
`:index()` this is allowed to be out\-of\-bounds, in which we return `nil`\.

```lua
local function _setCursor(historian, cursor)
   historian.cursor = cursor
   local line = historian[cursor]
   if not line then
      return nil, nil
   end
   local line_id = historian.line_ids[cursor]
   return line, historian:resultsFor(line_id)
end
```


### Historian:delta\(\), :prev\(\), :next\(\)

Moves the cursor by the given delta, returning the line
and result \(if any\) at the new cursor position\.

```lua
function Historian.delta(historian, delta)
   return _setCursor(historian,
                     clamp(historian.cursor + delta, 1, historian.n + 1))
end

function Historian.prev(historian)
   return historian:delta(-1)
end
function Historian.next(historian)
   return historian:delta(1)
end
```


### Historian:index\(cursor\)

  Loads the history to an exact index\. The index must be one that actually
exists, i\.e\. 1 <= index <= historian\.n\-\-historian\.n \+ 1 is not allowed\.

```lua
function Historian.index(historian, cursor)
   assert(inbounds(cursor, 1, historian.n))
   return _setCursor(historian, cursor)
end
```


### Historian:atEnd\(\), :toEnd\(\)

Answer whether the cursor is at the end of the history \(really off the end, ready for the next line\), or move it there\.
Note this is outside the bounds of what is allowed via `:index()`\.

```lua
function Historian.atEnd(historian)
   return historian.cursor > historian.n
end

function Historian.toEnd(historian)
   historian.cursor = historian.n + 1
end
```


### Historian:close\(\)

This should do everything an Historian wants to do when helm quits\.

Currently, it just saves the end of the run\.

```lua
function Historian.close(historian)
   historian.stmts.insert_run_finish :bind(historian.run.run_id) :step()
   if historian.idler then
      historian.idler:close()
   end
end
```


### Historian\(helm\_db\)

Creates a new `historian`\.

`helm_db` is an optional string parameter to load a non\-standard helm database\.


##### Metatable for result buffer

We need this so that attempts to \_\_repr the result buffer don't produce an
infinite loop\.

```lua
local __result_buffer_M = meta {}
function __result_buffer_M.__repr(buf, window, c)
   return c.alert "cowardly refusing to print result_buffer to avoid infinite appending"
end

local function new(helm_db)
   s.verbose = true
   local historian = setmetatable({}, Historian)
   historian.line_ids = {}
   historian.cursor = 0
   historian.cursor_start = 0
   historian.n = 0
   historian.lines_available = 0
   historian.result_queue = Deque()
   historian.result_buffer = setmetatable({}, __result_buffer_M)

   historian:createPreparedStatements(helm_db)
   historian:load()
   s.verbose = false
   return historian
end

Historian.idEst = new
```

```lua
return new
```
