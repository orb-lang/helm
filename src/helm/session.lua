






































local meta = assert(require "core:meta" . meta)
local helm_db = require "helm:helm-db"
local valiant = require "valiant:valiant"
local names = require "repr:names"
local Session = meta {}
local new









function Session.premiseCount(session)
   local count = 0
   for _, premise in ipairs(session) do
      if premise.status == "accept" or premise.status == "reject" then
         count = count + 1
      end
   end
   return count
end







function Session.passCount(session)
   local count = 0
   for _, premise in ipairs(session) do
      if premise.status == "accept" and premise.same then
         count = count + 1
      end
   end
   return count
end










local tabulate = assert(require "repr:persist-tabulate" . tabulate)
function Session.evaluate(session, isolated, historian)
   local ENV, aG
   if isolated then
      ENV = setmetatable({ core = core }, {__index = _G})
      aG = setmetatable({}, {__index = assert(names.anti_G)})
   else
      ENV = _G
      aG = assert(names.anti_G)
   end
   local eval = valiant(ENV, nil, aG)
   for _, premise in ipairs(session) do
      local ok, result = eval(premise.line)
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

function Session.load(session)
   if not session.session_id then
      local result = session.stmts.get_session_by_project_and_title
                        :bind(session.project_id, session.session_title)
                        :step()
      if not result then
         -- #todo This should probably raise an error that helm.orb handles,
         -- but Pylon would then need to understand the idea of a dirty exit,
         -- so for now, we can just exit directly.
         io.stderr:write('No session named "', session.session_title,
            '" found. Use br helm -n to create a new session.\n')
         os.exit(1)
      end
      session.session_id = result[1]
   end
   local stmt = session.stmts.get_session_by_id
                  :bind(session.session_id)
   for result in stmt:rows() do
      if not session.title then
         session.title = result.session_title
      end
      if session.accepted == nil then
         session.accepted = result.session_accepted
      end
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









function Session.append(session, line_id, line, results)
   -- Require manual approval of all lines by default,
   -- but do include them in the session, i.e. start with 'ignore' status
   local status = 'ignore'
   -- In macro mode we instead accept all lines with results by default
   if session.mode == "macro" and results then
      status = 'accept'
   end
   local premise = {
      title = "",
      status = status,
      line = line,
      old_line_id = nil,
      line_id = line_id,
      live_result = results,
      old_result = nil, -- These will be filled in later once generated
      new_result = nil
   }
   _appendPremise(session, premise)
end










function Session.resultsAvailable(session, line_id, results)
   for _, premise in ipairs(session) do
      if premise.line_id == line_id then
         premise.new_result = _wrapResults(results)
         break
      end
   end
end









local compact = assert(require "core:table" . compact)
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
   -- First, remove any "skip"ped premises from the session
   for i, premise in ipairs(session) do
      if premise.status == "skip" then session[i] = nil end
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



new = function(db, cfg)
   local session = meta(Session)
   session.stmts = helm_db.session(db)
   session.n = 0
   for k, v in pairs(cfg) do
      session[k] = v
   end
   return session
end



Session.idEst = new
return new

