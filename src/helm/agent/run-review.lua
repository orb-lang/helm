








local table = core.table




local ReviewAgent = require "helm:agent/review"
local RunReviewAgent = meta(getmetatable(ReviewAgent))






local insert = assert(table.insert)
function RunReviewAgent.update(agent, lines)
   agent.subject = {}
   while not lines:isEmpty() do
      insert(agent.subject, { line = lines:pop(), status = "keep" })
   end
   agent.selected_index = #agent.subject == 0 and 0 or 1
   agent:_updateResultsAgent()
   -- Update any EditAgents we have without creating any more
   for index in pairs(agent.edit_agents) do
      agent:_updateEditAgent(index)
   end
   agent:contentsChanged()
end









RunReviewAgent.valid_statuses = { "keep", "trash", "insert" }












local remove = assert(table.remove)
function RunReviewAgent.setSelectedState(agent, state)
   local premise = agent:selectedPremise()
   if premise.status == state then return end
   if premise.status == "insert" then
      -- Switching out of special "insert" state,
      -- remove temporary blank line
      remove(agent.subject, agent.selected_index + 1)
      -- Remove the *last* EditAgent iff there is one,
      -- then update the others to preserve bindings
      agent.edit_agents[#agent.subject + 1] = nil
      agent:bufferCommand("editAgentRemoved", #agent.subject + 1)
      for i = agent.selected_index + 1, #agent.subject do
         agent:_updateEditAgent(i)
      end
   elseif state == "insert" then
      -- Switching to special "insert" state,
      -- add a blank line below the selected premise
      -- Use an otherwise-invalid state--this line should never be selected
      -- except when editing it, so it cannot receive a Tab keypress
      insert(agent.subject, agent.selected_index + 1, { line = "", status = "ignore" } )
      for i = agent.selected_index + 1, #agent.subject do
         agent:_updateEditAgent(i)
      end
   end
   return ReviewAgent.setSelectedState(agent, state)
end









local clamp = assert(core.math.clamp)
function RunReviewAgent.selectIndex(agent, index)
   index = #agent.subject == 0
      and 0
      or clamp(index, 1, #agent.subject)
   if index ~= agent.selected_index
      and agent:selectedPremise().status == "insert" then
      agent:setSelectedState("keep")
   end
   ReviewAgent.selectIndex(agent, index)
end










function RunReviewAgent.selectNextWrap(agent)
   if agent:selectedPremise().status == "insert"
      and agent.selected_index + 1 == #agent.subject then
      return agent:selectIndex(1)
   else
      return ReviewAgent.selectNextWrap(agent)
   end
end








function RunReviewAgent.editInsertedLine(agent)
   if agent:selectedPremise().status ~= "insert" then
      return false
   end
   agent :send { method = "pushMode", "edit_line"}
end









function RunReviewAgent.cancelInsertEditing(agent)
   agent :send { to = "agents.edit", method = "clear" }
   agent :send { method = "popMode" }
end








function RunReviewAgent.acceptInsertion(agent)
   local line = agent :send { to = "agents.edit", method = "contents" }
   agent :send { to = "agents.edit", method = "clear" }
   local new_premise = agent.subject[agent.selected_index + 1]
   new_premise.line = line
   new_premise.status = "keep"
   agent:_updateEditAgent(agent.selected_index + 1)
   -- Switch out the status without going through the usual channels
   -- so that we don't remove the newly-added premise in the process
   agent:selectedPremise().status = "keep"
   agent:selectNextWrap()
   send { method = "popMode" }
end








local Deque = require "deque:deque"
function RunReviewAgent.evalAndResume(agent)
   -- Clear out any insertion-in-progress
   if agent:selectedPremise().status == "insert" then
      agent:setSelectedState("keep")
   end
   local to_run = Deque()
   for _, premise in ipairs(agent.subject) do
      if premise.status == "keep" then
         to_run:push(premise.line)
      end
   end
   agent :send { method = "rerun", to_run }
   agent :send { method = "pushMode", "nerf" }
end




return core.cluster.constructor(RunReviewAgent)

