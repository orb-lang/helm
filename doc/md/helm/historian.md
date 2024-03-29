# Historian


This module is responsible for REPL history\.

Historian loads old records of lines and results from a SQLite database, as
well as persisting new ones to the same store\.

It is also responsible for fuzzy searching across the last `HISTORY_LIMIT` of
records\.


#### imports

```lua
local uv      = require "luv"

local Session = require "helm:session"
local persist_tabulate = require "repr:persist-tabulate"
local helm_db = require "helm:helm-db"

local insert = assert(table.insert)
local meta = require "core/meta" . meta

local Set = require "set:set"
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

### Historian:load\(\)

Brings up the project history and result ids\.

Most of the complexity serves to make a simple key/value relationship
between the lines and their associated result history\.

We want as much history as practical, because we search in it, but most of
the results never get used\.

As much of the work as possible is offloaded to a uv idler process\.

```lua
local clamp, inbounds = import("core:core/math", "clamp", "inbounds")
local assertfmt = import("core:core/string", "assertfmt")
local format = assert(string.format)

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
   -- Retrieve history
   local number_of_lines = stmts.get_number_of_lines
                             :bind(project_id):step()[1]
   if number_of_lines == 0 then
      return nil
   end
   number_of_lines = clamp(number_of_lines, nil, historian.HISTORY_LIMIT)
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
   historian.stmts.savepoint_persist()
   historian.insert_line:bindkv { project = historian.project_id,
                                  line    = blob(line) }
   local err = historian.insert_line:step()
   if not err then
      historian.insert_line:clearbind():reset()
   else
      error(err)
   end
   local line_id = historian.stmts.lastRowId()
   insert(historian.line_ids, line_id)
   -- If there's nothing to persist, release our savepoint
   -- and don't bother starting the idler
   if not results then
      historian.stmts.release_persist()
      return line_id
   end

   local persist_cb = tabulate_some(results)
   local persist_idler = uv.new_idle()
   historian.idlers:insert(persist_idler)
   persist_idler:start(function()
      local done, results_tostring = persist_cb()
      if not done then return nil end
      -- inform the Session that persisted results are available
      historian.session:resultsAvailable(line_id, results_tostring)
      -- now persist
      for i = 1, results.n do
         local hash = sha(results_tostring[i])
         historian.insert_repr:bind(hash, results_tostring[i])
         err = historian.insert_repr:step()
         if not err then
            historian.insert_repr :clearbind() :reset()
         else
            error(err)
         end
         historian.insert_result_hash:bind(line_id, hash)
         err = historian.insert_result_hash:step()
         if not err then
            historian.insert_result_hash :clearbind() :reset()
         else
            error(err)
         end
      end
      historian.stmts.release_persist()
      persist_idler:stop()
      assert(historian.idlers:remove(persist_idler) == true)
   end)
   return line_id
end
```


### Historian:append\(line, results, success\)

As :persist\(\), but also appends to the history and the current session\.

Doesn't adjust the cursor, but does store the results in the result\_buffer\.

```lua
function Historian.append(historian, line, results, success)
   if line == "" or line == historian[historian.n] then
      -- don't bother
      return false
   end
   historian.n = historian.n + 1
   historian[historian.n] = line
   if not success then results = nil end
   historian.result_buffer[historian.n] = results
   local line_id = historian:persist(line, results)
   historian.session:append(line_id, line, results)
   return true
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
local db_result_M = assert(persist_tabulate.db_result_M)

local function _setCursor(historian, cursor)
   historian.cursor = cursor
   local line = historian[cursor]
   if not line then
      return nil, nil
   end
   if historian.result_buffer[cursor] then
      return line, historian.result_buffer[cursor]
   end
   local line_id = historian.line_ids[cursor]
   local stmt = historian.get_results
   stmt:bindkv {line_id = line_id}
   local results = stmt :resultset 'i'
   if results then
      results = results[1]
      results.n = #results
      for i = 1, results.n do
         -- stick the result in a table to enable repr-ing
         results[i] = {results[i]}
         setmetatable(results[i], db_result_M)
      end
   end
   stmt:reset()
   -- may as well memoize the database call, while we're here
   historian.result_buffer[line_id] = results
   return line, results
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
   local historian = meta(Historian)
   historian.line_ids = {}
   historian.cursor = 0
   historian.cursor_start = 0
   historian.n = 0
   historian:createPreparedStatements(helm_db)
   historian:load()
   local session_cfg = {}
   local session_title = _Bridge.args.macro or
                         _Bridge.args.new_session or
                         _Bridge.args.session
   if _Bridge.args.macro then
      session_cfg.accepted = true
      session_cfg.mode = "macro"
   end
   local sesh = Session(helm_db,
                        historian.project_id,
                        session_title,
                        session_cfg)
   -- Asked to create a session that already exists
   if (_Bridge.args.new_session or _Bridge.args.macro) and sesh.session_id then
      error('A session named "' .. session_title ..
            '" already exists. You can review it with br helm -s.')
   end
   if _Bridge.args.session then
      if sesh.session_id then
         sesh:loadPremises()
      else
         -- Asked to review a session that doesn't exist
         error('No session named "' .. session_title ..
               '" found. Use br helm -n to create a new session.')
      end
   end
   historian.session = sesh
   historian.result_buffer = setmetatable({}, __result_buffer_M)
   historian.idlers = Set()
   return historian
end

Historian.idEst = new
```

```lua
return new
```
