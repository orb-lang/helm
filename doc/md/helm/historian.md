# Historian


This module is responsible for REPL history\.

Historian loads old records of lines and results from a SQLite database, as
well as persisting new ones to the same store\.

It is also responsible for fuzzy searching across the last `HISTORY_LIMIT` of
records\.


#### imports

```lua
local core = require "qor:core"
local math = core.math
local insert = assert(table.insert)

local uv      = require "luv"

local bridge = require "bridge"

local s = require "status:status" ()

local Session = require "helm:session"
local persist_tabulate = require "repr:persist-tabulate"
local helm_db = require "helm:helm-db"

local Deque = require "deque:deque"
local Round = require "helm:round"
```


### Historian metatable

```lua
local Historian = core.cluster.meta {}
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
local clamp, inbounds = assert(math.clamp), assert(math.inbounds)

function Historian.load(historian)
   local stmts = historian.stmts
   -- Retrieve project id
   local project_id = stmts.get_project
                                      : bind(historian.project)
                                      : value()
   if not project_id then
      sql_insert_errcheck(stmts.insert_project : bind(historian.project))
      -- retry
      project_id = stmts.get_project  : bind(historian.project)
                                    : value()
      if not project_id then
         error "Could not create project in .bridge"
      end
   end
   historian.project_id = project_id

   -- start the latest run
   sql_insert_errcheck(stmts.insert_run_start :bind(project_id))
   historian.run = { run_id = stmts.lastRowId(), actions = {} }

   -- Retrieve history
   local number_of_lines = stmts.get_number_of_lines : bind(project_id)
                                                     : value()
   if number_of_lines == 0 then
      return nil
   end
   number_of_lines = clamp(number_of_lines, nil, historian.HISTORY_LIMIT)
   historian.lines_available = number_of_lines
   local round_iter = stmts.get_recent
                      : bindkv { project = project_id,
                                 num_lines = number_of_lines }
                      : rows()
   historian.cursor = number_of_lines + 1
   historian.cursor_start = number_of_lines + 1
   historian.n = number_of_lines
   local counter = number_of_lines
   local idler
   local function load_one()
      local res = round_iter()
      if not res then
         if idler then idler:stop() end
         return nil
      end
      historian[counter] = Round(res)
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

Loads the previous run, ready to review or re\-evaluate, as \(aspirationally\) a
Deck of Rounds\.

\#todo
specifically a Session, but we do need the status behavior, so Premises work
for now\.

\#todo

```lua
local Premise = require "helm:premise"
local function _loadDeckFromStatement(historian, get_lines)
   local deck = {}
   for row in get_lines:rows() do
      local round = Round(row)
      historian:loadResponseFor(round)
      local premise = round:asPremise{ status = "keep" }
      insert(deck, premise)
   end
   return deck
end

function Historian.loadPreviousRun(historian)
   local prev_run_id = historian.stmts.get_latest_finished_run
                                       :bind(historian.project_id)
                                       :value()
   local get_lines = historian.stmts.get_lines_of_run:bind(prev_run_id)
   historian.previous_run = _loadDeckFromStatement(historian, get_lines)
end
```


### Historian:loadRecentLines\(num\_lines\)

Loads `num_lines` recent lines from the history and returns them in a format
similar to a Session, as above\.


```lua
local reverse = assert(core.table.reverse)
function Historian.loadRecentLines(historian, num_lines)
   -- we could duplicate this information off the historian array, if we
   -- had the patience to wait around for it to populate.
   --
   -- We probably should do it that way, actually, but there's too much
   -- handwaving about how runs interact with history already, and this
   -- works, as blocking code tends to, with minimum fuss.
   local get_lines = historian.stmts.get_recent
                : bindkv { project = historian.project_id,
                           num_lines = num_lines }
   local deck = _loadDeckFromStatement(historian, get_lines)
   if num_lines > #deck then
      s:warn("Requested %d lines to rerun, only %d lines available", num_lines, #deck)
   end
   -- Statement is optimized for loading history in newest-to-oldest order,
   -- but for this we need the original execution order, i.e. oldest-to-newest
   return reverse(deck)
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


### Historian:loadResponseFor\(round\)

Ensures that results are available for the provided `round`, retrieving them
from the database if needed and preferring "live" results over persisted ones
when available\.

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

function Historian.loadResponseFor(historian, round)
   if round:result() or not round.line_id then
      return
   end
   local stmt = historian.get_results
   stmt:bindkv(round)
   local results = {}
   for i, res in stmt:cols() do
      results[i] = res
   end
   round:setDBResponse(_wrapResults(results))
end
```


### Historian:persist\(line, results\)

Persists a line and results to store\.

```lua
local tabulate_some = assert(persist_tabulate.tabulate_some)
local sha = assert(require "util:sha" . shorthash)
local blob = assert(assert(sql, "sql must be in bridge _G").blob)


function Historian.persist(historian, round)
   if round:isBlank() then
      -- A blank line can have no results and is uninteresting.
      return false
   end

   -- Persist the line of input itself
   sql_insert_errcheck(
      historian.insert_line:bindkv { project = historian.project_id,
                                     line    = blob(round:getLine()) })
   round.line_id = historian.stmts.lastRowId()

   -- Then the run action indicating it was just evaluated
   local run_action = { run_id  = historian.run.run_id,
                        ordinal = #historian.run.actions + 1,
                        input   = round.line_id }
   insert(historian.run.actions, run_action)
   sql_insert_errcheck(historian.stmts.insert_run_input:bindkv(run_action))

   -- If there are no results, nothing more to persist,
   -- release our savepoint and don't bother starting the idler
   if not round:hasResults() then
      return
   end

   local queue = historian.result_queue
   local persist_cb = tabulate_some(round:result())
   historian.idler = historian.idler or uv.new_idle()
   local empty = #queue == 0
   queue:push(pack(round, persist_cb))
   if empty then
      historian.idler:start(function()
         local round, cb = unpack(queue:peek())
         local done, results_tostring = cb()
         if not done then return nil end
         queue:pop()
         -- now persist
         for i = 1, round:result().n do
            local hash = sha(results_tostring[i])
            sql_insert_errcheck(historian.insert_repr:bind(hash, results_tostring[i]))
            sql_insert_errcheck(historian.insert_result_hash:bind(round.line_id, hash))
         end
         round.db_response = _wrapResults(results_tostring)
         if #queue == 0 then
            historian.idler:stop()
         end
      end)
   end
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


### Historian:append\(line, round\)

Append the \(just\-evaluated\) provided round to the history and current session\.
If this round was previously on the desk \(which it usually will have been, but
in case of rerun it might have come from outside\), place a new blank round on
the desk to continue working with\.

\#todo

Note we do not adjust the cursor\.

```lua
function Historian.append(historian, round)
   if round:isBlank() then
      return false
   end
   historian:persist(round)
   historian.n = historian.n + 1
   historian[historian.n] = round
   -- #todo this should be an Action--actually we should be in a handler for
   -- one action (e.g. 'evalCompleted') and issue another (e.g. 'lineStored')
   if historian.session then
      historian.session:append(round)
   end
   if round == historian.desk then
      historian.desk = Round()
   end
   return true
end
```


### Historian:stashLine\(line\)

Stashes any changes in the provided `line` to the round on the desk\.

\#todo
do nothing, but this will become obsolete with card mode\. \(Indeed this method
will become part of the Deck, with altered behavior\.\)


```lua
function Historian.stashLine(historian, line)
   local round = historian[historian.cursor]
   if round and line == round:getLine() then return end
   historian.desk:setLine(line)
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
   local result = SelectionList(frag, { show_shortcuts = true, cursors = {}})
   -- Empty string means no results, not everything,
   -- so just don't bother searching
   if frag == "" then
      return result
   end
   local function try_search()
      local patt = fuzz_patt(result.frag)
      local dup = {}
      for i = historian.n, 1, -1 do
         local item_str = tostring(historian[i]:getLine())
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


### Historian:delta\(\), :prev\(\), :next\(\)

Moves the cursor by the given delta, returning the line
and result \(if any\) at the new cursor position\.

```lua
function Historian.delta(historian, delta)
   return historian:index(clamp(historian.cursor + delta, 1, historian.n + 1))
end

function Historian.prev(historian)
   return historian:delta(-1)
end
function Historian.next(historian)
   return historian:delta(1)
end
```


### Historian:index\(cursor\)

  Loads the history to an exact index\. This index may be historian\.n \+ 1,
which is a pseudo\-index corresponding to the `desk`\.

```lua
function Historian.index(historian, cursor)
   assert(inbounds(cursor, 1, historian.n + 1))
   historian.cursor = cursor
   if cursor == historian.n + 1 then
      return historian.desk
   else
      local round = historian[cursor]
      historian:loadResponseFor(round)
      return round
   end
end
```


### Historian:toEnd\(\)

Move the cursor to the end of the history\-\-off the end, in fact\. This
is usually a new blank round, ready for the next line, and if one doesn't
exist, we will create it\.

```lua
function Historian.toEnd(historian)
   historian.cursor = historian.n + 1
   return historian.desk
end
```


### Historian:close\(\)

This should do everything an Historian wants to do when helm quits\.

Currently, it just saves the end of the run\.

```lua
function Historian.close(historian)
   if #historian.run.actions > 0 then
      sql_insert_errcheck(historian.stmts.insert_run_finish
                             :bind(historian.run.run_id))
   else
      -- #todo this is wrong anyway but let's skip this crap
   end
   if historian.idler then
      historian.idler:close()
   end
end
```


### Historian\(helm\_db\)

Creates a new `historian`\.

`helm_db` is an optional string parameter to load a non\-standard helm database\.

```lua
local function new(helm_db)
   s.verbose = true
   local historian = setmetatable({}, Historian)
   historian.cursor = 0
   historian.cursor_start = 0
   historian.n = 0
   historian.lines_available = 0
   historian.result_queue = Deque()
   historian.desk = Round()

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
