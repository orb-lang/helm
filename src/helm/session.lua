









































local Round = require "helm:round"

local table = core.table




local helm_db = require "helm:helm-db"
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










local function _appendPremise(session, premise)
   session.n = session.n + 1
   session[session.n] = premise
end

function Session.loadPremises(session)
   local stmt = session.stmts.get_session_by_id
                  :bind(session.session_id)
   for result in stmt:rows() do
      -- Left join may produce (exactly one) row with no status value,
      -- indicating that we have no premises
      if result.status then
         local round = Round(result)
         send { to = 'hist', method = 'loadResultsFor', round }
         local premise = {
            title = result.title,
            status = result.status,
            round = round
         }
         _appendPremise(session, premise)
      end
   end
end








function Session.append(session, round)
   -- Require manual approval of all lines by default,
   -- but do include them in the session, i.e. start with 'ignore' status
   local premise = {
      title = "",
      status = 'ignore',
      round = round,
   }
   _appendPremise(session, premise)
end









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
            :bindkv(premise) -- Pick up title and status
            :bindkv(premise.round) -- Pick up line_id
            :step()
   end
   session.stmts.commit()
end












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



Session.idEst = new
return new

