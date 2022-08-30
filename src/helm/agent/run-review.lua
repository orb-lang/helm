








local table = core.table

local Round = require "helm:round"




local ReviewAgent = require "helm:agent/review"
local RunReviewAgent = meta(getmetatable(ReviewAgent))









local insert = assert(table.insert)
function RunReviewAgent.setInitialSelection(agent)
   if #agent.subject == 0 then
      insert(agent.subject, { line = "", status = "insert" })
   end
   agent.selected_index = 1
end



















RunReviewAgent.valid_statuses = { "keep", "insert", "trash" }
RunReviewAgent.was_inserting = false












local function _updateAgentsAfterSelected(agent)
   for i = agent.selected_index, #agent.subject do
      agent:_updateEditAgent(i)
   end
   agent:_updateResultsAgent()
end

function RunReviewAgent.insertLine(agent)
   insert(agent.subject, agent.selected_index, { status = "insert", round = Round() } )
   _updateAgentsAfterSelected(agent)
end











local remove = assert(table.remove)
function RunReviewAgent.cancelInsertion(agent)
   if agent:selectedPremise().status ~= "insert"
      -- Don't remove an "insert" premise if it's the very last one
      or #agent.subject == 1 then
         return
   end

   remove(agent.subject, agent.selected_index)
   -- Remove the *last* EditAgent iff there is one,
   -- then update the others to preserve bindings
   agent.edit_agents[#agent.subject + 1] = nil
   agent:bufferCommand("editAgentRemoved", #agent.subject + 1)
   _updateAgentsAfterSelected(agent)
   agent.was_inserting = true
end









function RunReviewAgent.setSelectedState(agent, state)
   local premise = agent:selectedPremise()
   if premise.status == state then return end
   -- Any status change clears the `was_inserting` flag, *except* canceling
   -- out of insertion, which sets it instead. Save it locally and clear it
   -- before deciding what to do, that way it can just be *re*-set in the
   -- one case that needs it.
   local was_inserting = agent.was_inserting
   agent.was_inserting = false
   if state == "insert" then
      if was_inserting then
         -- #todo this is dependent on only having two non-insert statuses,
         -- if there were more, we would need to know the intended
         -- cycle direction, so this would need to become an assertion failure
         -- and we would have to handle this in overrides of
         -- :[reverse]ToggleSelectedState
         state = premise.status == "keep" and "trash" or "keep"
         ReviewAgent.setSelectedState(agent, state)
      else
         agent:insertLine()
      end
   else
      -- Need to explicitly check here because we don't want to change another
      -- premise's status when canceling out of insertion. Setting the flag
      -- means the change will occur the *next* time tab is pressed
      if premise.status == "insert" then
         agent:cancelInsertion()
      else
         ReviewAgent.setSelectedState(agent, state)
      end
   end
end











function RunReviewAgent.selectionChanged(agent)
   agent.was_inserting = false
   ReviewAgent.selectionChanged(agent)
end














function RunReviewAgent.selectIndex(agent, index)
   agent:cancelInsertion()
   ReviewAgent.selectIndex(agent, index)
end
function RunReviewAgent.selectNextWrap(agent)
   agent:cancelInsertion()
   ReviewAgent.selectNextWrap(agent)
end
function RunReviewAgent.selectPreviousWrap(agent)
   agent:cancelInsertion()
   ReviewAgent.selectPreviousWrap(agent)
end








function RunReviewAgent.editInsertedLine(agent)
   if agent:selectedPremise().status ~= "insert" then
      return false
   end
   agent :send { method = "pushMode", "edit_line"}
end








function RunReviewAgent.cancelInsertEditing(agent)
   agent:cancelInsertion()
   agent :send { to = "agents.edit", method = "clear" }
   agent :send { method = "popMode" }
end








function RunReviewAgent.acceptInsertion(agent)
   local line = agent :send { to = "agents.edit", method = "contents" }
   if line:find("^%s*$") then
      agent:cancelInsertEditing()
      return
   end
   agent :send { to = "agents.edit", method = "clear" }
   local premise = agent:selectedPremise()
   premise.round.line = line
   -- Switch out the status without going through the usual channels
   -- so that we don't remove the newly-added premise in the process
   premise.status = "keep"
   agent:_updateEditAgent(agent.selected_index)
   agent:selectNextWrap()
   send { method = "popMode" }
end








local Deque = require "deque:deque"
function RunReviewAgent.evalAndResume(agent)
   -- Clear out any insertion-in-progress
   agent:cancelInsertion()
   local to_run = Deque()
   for _, premise in ipairs(agent.subject) do
      if premise.status == "keep" then
         to_run:push(premise.round)
      end
   end
   agent :send { to = "agents.status", method = "update", "default" }
   agent :send { method = "pushMode", "nerf" }
   agent :send { method = "rerun", to_run }
end




return core.cluster.constructor(RunReviewAgent)

