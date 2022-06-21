# Session


  `helm` is expected to have a **session mode**, where it runs a sequence of
commands, and optionally validates some or all of the results\.

There will be a way to run these headlessly, which will also help in
refactoring `modeselektor` to have no information about how display is
happening\.

A session will have a Session object, called `sesh` by default, which will
have some methods:

`sesh:pin(to_pin)` will take a number or the string "all", and pin that
step of the session\.

This means that it expects the same result, and will inform the user if it
isn't\.

`sesh:unpin(to_unpin)` will do the opposite\.

Both return the session object, which has a `__repr` which is informative of
these statuses and, for pinned objects, if they have passed on the last round\.

`sesh:add(string)` will execute a string, and add it to a session\.
`sesh:addLast(pin=(true|false))` and `sesh:addNext()` will add the last
line, optionally pinning it, or flag the session to add the next line\.

`sesh:record()` and `sesh:stop()` will start and stop recording a session\.
`^R` or `sesh:reset()` will reload the session, and return the session object
with changes to pinned lines noted\.

It's intended that any changes to files the session depends on, will also
trigger a session reset\.

A session will load the session lines into the history buffer, but only once,
no matter how many times the session is reset or run\.


#### imports

```lua
local table = core.table
```


```lua
local helm_db = require "helm:helm-db"
local Session = meta {}
local new
```

### Session:premiseCount\(\), :passCount\(\)

The number of non\-ignored \(accepted or rejected\) premises in the session\.
Note that during review we may have trashed premises as well, so we
cannot just check status ~= "ignore"\.

```lua
function Session.premiseCount(session)
   local count = 0
   for _, premise in ipairs(session) do
      if premise.status == "accept" or premise.status == "reject" then
         count = count + 1
      end
   end
   return count
end
```

### Session:passCount\(\)

The number of "passing" premises \(accepted premises with matching output\)

```lua
function Session.passCount(session)
   local count = 0
   for _, premise in ipairs(session) do
      if premise.status == "accept" and premise.same then
         count = count + 1
      end
   end
   return count
end
```

### Session:evaluate\(isolated, historian\)

\(Re\-\)Evaluates the session and determines pass/fail state for all its premises\.
If `isolated` is set, avoids mutating \_G by creating a temporary wrapper environment\.

If a Historian is provided, appends the results of the re\-evaluation to it\.

```lua
local tabulate = assert(require "repr:persist-tabulate" . tabulate)
function Session.evaluate(session, valiant, historian)
   for _, premise in ipairs(session) do
      local ok, result = valiant(premise.line)
      -- #todo handle errors here

      -- Avoid empty results
      if result and result.n > 0 then
         premise.live_result = result
         -- #todo have the Historian handle this!
         premise.new_result = tabulate(result, aG)
      end
      if premise.old_result and premise.new_result
         and #premise.old_result == #premise.new_result then
         premise.same = true
         for i = 1, #premise.old_result do
            if premise.old_result[i] ~= premise.new_result[i] then
               premise.same = false
               break
            end
         end
      elseif (not premise.old_result) and (not premise.new_result) then
         premise.same = true
      else
         premise.same = false
      end
   end
end
```


### Session:loadPremises\(\)

Loads the session from the database, retrieving its lines and results\.
Does not re\-run the lines\.

```lua

local function _appendPremise(session, premise)
   session.n = session.n + 1
   session[session.n] = premise
end

-- #todo we should ideally ask the Historian for these results,
-- in case it already has them
local db_result_M = assert(require "repr:persist-tabulate" . db_result_M)
local function _wrapResults(results)
   local wrapped = { n = #results }
   for i = 1, wrapped.n do
      wrapped[i] = setmetatable({results[i]}, db_result_M)
   end
   return wrapped
end

local function _loadResults(session, premise)
   local stmt = session.stmts.get_results
   local results = stmt:bind(premise.old_line_id):resultset()
   if results then
      results = _wrapResults(results.repr)
   end
   premise.old_result = results
   stmt:reset()
end

function Session.loadPremises(session)
   local stmt = session.stmts.get_session_by_id
                  :bind(session.session_id)
   for result in stmt:rows() do
      -- Left join may produce (exactly one) row with no status value,
      -- indicating that we have no premises
      if result.status then
         local premise = {
            title = result.title,
            status = result.status,
            line = result.line,
            old_line_id = result.line_id,
            line_id = result.line_id, -- These will be filled if/when we re-run
            live_result = nil,
            old_result = nil, -- Need a separate query to load this
            new_result = nil
         }
         _loadResults(session, premise)
         _appendPremise(session, premise)
      end
   end
end
```


### Session:append\(line\_id\)

Appends the line with the given id as a new premise\. The session mode
determines whether it is marked as accepted or not\.

```lua
function Session.append(session, line_id, line, results)
   -- Require manual approval of all lines by default,
   -- but do include them in the session, i.e. start with 'ignore' status
   local premise = {
      title = "",
      status = 'ignore',
      line = line,
      old_line_id = nil,
      line_id = line_id,
      live_result = results,
      old_result = nil, -- These will be filled in later once generated
      new_result = nil
   }
   _appendPremise(session, premise)
end
```


### Session:resultsAvailable\(line\_id, results\)

Notification from the Historian that an idler has finished stringifying results
for a particular line\_id\. If that line\_id is part of this session, attach
the results to the appropriate premise\.

```lua
function Session.resultsAvailable(session, line_id, results)
   for _, premise in ipairs(session) do
      if premise.line_id == line_id then
         premise.new_result = _wrapResults(results)
         break
      end
   end
end
```


### Session:save\(\)

Save the current state of the session to the database\. For simplicity's sake,
we always just save everything, without checking whether it has changed\.

```lua
local compact = assert(table.compact)
function Session.save(session)
   session.stmts.beginTransaction()
   -- If the session itself hasn't been stored yet, do so and retrieve its id
   if not session.session_id then
      session.stmts.insert_session:bindkv(session):step()
      session.session_id = session.stmts.lastRowId()
   -- Otherwise possibly update its title and accepted status
   else
      session.stmts.update_session:bindkv(session):step()
   end
   -- First, remove any trashed premises from the session
   for i, premise in ipairs(session) do
      if premise.status == "trash" then session[i] = nil end
   end
   compact(session)
   -- And now from the DB (the query picks up session.n directly)
   session.stmts.truncate_session:bindkv(session):step()
   -- Now insert all of our premises--anything that is already there
   -- will be replaced thanks to ON CONFLICT REPLACE
   for i, premise in ipairs(session) do
      session.stmts.insert_premise
            :bindkv{ session_id = session.session_id, ordinal = i }
            :bindkv(premise)
            :step()
   end
   session.stmts.commit()
end
```


### Session\(db, project\_id, title\_or\_index, cfg\)

Searches the database for a session with the given title \(if a string\) or
index within the list of sessions for the project \(if a number\) and retrieves
its core information \(ID, title, accepted\)\. If one is not found, creates a
new, empty session with the given title, which MUST be a non\-integer string in
this case\. \(Note that this is assured by the command\-line argument parser\.\)

```lua
local collect = assert(table.collect)
new = function(db, project_id, title_or_index, cfg)
   local session = setmetatable({}, Session)
   session.stmts = helm_db.session(db)
   session.project_id = project_id
   session.n = 0
   if type(title_or_index) == "number" then
      local stmt = session.stmts.get_sessions_for_project
      stmt:bind(session.project_id)
      local results = collect(stmt.rows, stmt)
      stmt:clearbind():reset()
      -- An index can only be used when intending to load
      -- so out-of-bounds is an immediate error
      if #results < title_or_index then
         error(('Cannot load session #%d, only %d available.')
                  :format(title_or_index, #results))
      end
      local result = results[title_or_index]
      session.session_id = result.session_id
      session.session_title = result.session_title
      session.accepted = result.accepted ~= 0
   else
      session.session_title = title_or_index
      local result = session.stmts.get_session_by_project_and_title
                        :bind(session.project_id, session.session_title)
                        :stepkv()
      if result then
         session.session_id = result.session_id
         session.accepted = result.accepted ~= 0
      end
   end
   if cfg then
      for k, v in pairs(cfg) do
         session[k] = v
      end
   end
   return session
end
```

```lua
Session.idEst = new
return new
```
