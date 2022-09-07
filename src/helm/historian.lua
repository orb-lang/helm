














local uv      = require "luv"

local bridge = require "bridge"

local s = require "status:status" ()

local Session = require "helm:session"
local persist_tabulate = require "repr:persist-tabulate"
local helm_db = require "helm:helm-db"

local insert = assert(table.insert)

local Deque = require "deque:deque"
local Round = require "helm:round"






local Historian = meta {}
Historian.HISTORY_LIMIT = 2000
Historian.helm_db_home = helm_db.helm_db_home
Historian.project = uv.cwd()





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









local function sql_insert_errcheck(stmt)
   local err = stmt:step()
   stmt:clearbind():reset()
   if err then
      error(err)
   end
end

















local math = core.math
local clamp, inbounds = assert(math.clamp), assert(math.inbounds)

function Historian.load(historian)
   local stmts = historian.stmts
   -- Retrieve project id
   local project_id = stmts.get_project
                                      : bind(historian.project)
                                      : value()
   if not project_id then
      stmts.insert_project : bind(historian.project)
                           : step()
      -- retry
      project_id = stmts.get_project  : bind(historian.project)
                                    : value()
      if not project_id then
         error "Could not create project in .bridge"
      end
   end
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
      local res = pop_stmt:stepkv()
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











function Historian.loadPreviousRun(historian)
   local prev_run_id = historian.stmts.get_latest_finished_run
                                       :bind(historian.project_id)
                                       :value()
   local run = {}
   for row in historian.stmts.get_lines_of_run:bind(prev_run_id):rows() do
      local round = Round(row)
      historian:loadResultsFor(round)
      local premise = {
         status = "keep",
         round = round
      }
      insert(run, premise)
   end
   historian.previous_run = run
end








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
   for row in get_lines:rows() do
      deque:push(Round(row))
   end
   deque:reverse()
   return deque
end












function Historian.loadOrCreateSession(historian, session_title)
   historian.session = Session(historian.helm_db_home,
                        historian.project_id,
                        session_title)
end










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

function Historian.loadResultsFor(historian, round)
   if round:results() or not round.line_id then
      return
   end
   local stmt = historian.get_results
   stmt:bindkv(round)
   local results = stmt :resultset 'i'
   if results then
      results = _wrapResults(results[1])
   end
   round.db_result = results
   stmt:reset()
end








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
                                     line    = blob(round.line) })
   round.line_id = historian.stmts.lastRowId()

   -- Then the run action indicating it was just evaluated
   local run_action = { run_id  = historian.run.run_id,
                        ordinal = #historian.run.actions + 1,
                        input   = round.line_id }
   insert(historian.run.actions, run_action)
   sql_insert_errcheck(historian.stmts.insert_run_input:bindkv(run_action))

   -- If there are no results, nothing more to persist,
   -- release our savepoint and don't bother starting the idler
   if not round:results() or round:results().n == 0 then
      return
   end

   local queue = historian.result_queue
   local persist_cb = tabulate_some(round:results())
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
         for i = 1, round:results().n do
            local hash = sha(results_tostring[i])
            sql_insert_errcheck(historian.insert_repr:bind(hash, results_tostring[i]))
            sql_insert_errcheck(historian.insert_result_hash:bind(round.line_id, hash))
         end
         round.db_result = _wrapResults(results_tostring)
         if #queue == 0 then
            historian.idler:stop()
         end
      end)
   end
end








function Historian.idling(hist)
   if #hist.result_queue > 0 then
      return true
   else
      return false
   end
end















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













function Historian.stashLine(historian, line)
   local round = historian[historian.cursor]
   if round and line == round.line then return end
   historian.desk.line = line
end






























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
         local item_str = tostring(historian[i].line)
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












function Historian.delta(historian, delta)
   return historian:index(clamp(historian.cursor + delta, 1, historian.n + 1))
end

function Historian.prev(historian)
   return historian:delta(-1)
end
function Historian.next(historian)
   return historian:delta(1)
end









function Historian.index(historian, cursor)
   assert(inbounds(cursor, 1, historian.n + 1))
   historian.cursor = cursor
   if cursor == historian.n + 1 then
      return historian.desk
   else
      local round = historian[cursor]
      historian:loadResultsFor(round)
      return round
   end
end










function Historian.toEnd(historian)
   historian.cursor = historian.n + 1
   return historian.desk
end










function Historian.close(historian)
   if #historian.run.actions > 0 then
      historian.stmts.insert_run_finish :bind(historian.run.run_id) :step()
   else
      -- #todo this is wrong anyway but let's skip this crap
   end
   if historian.idler then
      historian.idler:close()
   end
end










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



return new

