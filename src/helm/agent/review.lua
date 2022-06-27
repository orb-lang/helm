








local EditAgent = require "helm:agent/edit"
local ResultsAgent = require "helm:agent/results"

local math = core.math
local assert = assert(core.fn.assertfmt)




local Agent = require "helm:agent/agent"
local ReviewAgent = meta(getmetatable(Agent))










function ReviewAgent.update(agent, run)
   agent.subject = run
   agent:setInitialSelection()
   agent:_updateResultsAgent()
   -- Update any EditAgents we have without creating any more
   for index in pairs(agent.edit_agents) do
      agent:_updateEditAgent(index)
   end
   agent:contentsChanged()
end









function ReviewAgent._updateEditAgent(agent, index)
   local edit_agent = agent.edit_agents[index]
   if edit_agent then
      edit_agent:update(agent.subject[index].line)
   end
end

function ReviewAgent._updateResultsAgent(agent)
   local results_agent = agent.results_agent
   if results_agent then
      local premise = agent:selectedPremise()
      local result = premise and (premise.new_result or premise.old_result)
      results_agent:update(result)
      -- #todo scroll offset of the Resbuf needs to be reset at this point
      -- we have some serious thinking to do about how changes are
      -- communicated to the buffer
   end
end













function ReviewAgent.selectionChanged(agent)
      agent:_updateResultsAgent()
      agent:contentsChanged()
      agent:bufferCommand("ensureSelectedVisible")
end








local clamp = assert(math.clamp)
function ReviewAgent.selectIndex(agent, index)
   index = #agent.subject == 0
      and 0
      or clamp(index, 1, #agent.subject)
   if index ~= agent.selected_index then
      agent.selected_index = index
      agent:selectionChanged()
   end
end









function ReviewAgent.selectNextWrap(agent)
   local new_idx = agent.selected_index < #agent.subject
      and agent.selected_index + 1
      or 1
   return agent:selectIndex(new_idx)
end
function ReviewAgent.selectPreviousWrap(agent)
   local new_idx = agent.selected_index > 1
      and agent.selected_index - 1
      or #agent.subject
   return agent:selectIndex(new_idx)
end






function ReviewAgent.selectedPremise(agent)
   return agent.subject[agent.selected_index]
end

















function ReviewAgent.toggleSelectedState(agent)
   local new_status = agent.status_cycle_map[agent:selectedPremise().status]
   return agent:setSelectedState(new_status)
end

function ReviewAgent.reverseToggleSelectedState(agent)
   local new_status = agent.status_reverse_map[agent:selectedPremise().status]
   return agent:setSelectedState(new_status)
end








function ReviewAgent.setSelectedState(agent, state)
   local premise = agent:selectedPremise()
   if premise.status == state then return end
   assert(agent.status_cycle_map[state], "Cannot change to invalid status %s", state)
   premise.status = state
   agent:contentsChanged()
   return true
end












local function _swap_premises(agent, index_a, index_b)
   local premise_a = agent.subject[index_a]
   local premise_b = agent.subject[index_b]

   agent.subject[index_a] = premise_b
   premise_b.ordinal = index_a
   agent:_updateEditAgent(index_a)

   agent.subject[index_b] = premise_a
   premise_a.ordinal = index_b
   agent:_updateEditAgent(index_b)

   agent:contentsChanged()
end

function ReviewAgent.movePremiseUp(agent)
   if agent.selected_index == 1 then
      return false
   end
   _swap_premises(agent, agent.selected_index, agent.selected_index - 1)
   -- Maintain selection of the same premise after the move
   -- Will never wrap because we disallowed moving the first premise up
   agent:selectPreviousWrap()
   return true
end

function ReviewAgent.movePremiseDown(agent)
   if agent.selected_index == #agent.subject then
      return false
   end
   _swap_premises(agent, agent.selected_index, agent.selected_index + 1)
   agent:selectNextWrap()
   return true
end









function ReviewAgent.bufferValue(agent)
   return agent.subject
end









function ReviewAgent.windowConfiguration(agent)
   return agent.mergeWindowConfig(Agent.windowConfiguration(), {
      field = { selected_index = true },
      closure = { selectedPremise = true,
                  editWindow = true,
                  resultsWindow = true }
   })
end








local inbounds = assert(math.inbounds)
local lua_thor = assert(require "helm:lex" . lua_thor)
function ReviewAgent.editWindow(agent, index)
   assert(inbounds(index, 1, #agent.subject))
   if not agent.edit_agents[index] then
      agent.edit_agents[index] = EditAgent()
      agent.edit_agents[index].lex = lua_thor
      agent:_updateEditAgent(index)
   end
   return agent.edit_agents[index]:window()
end










function ReviewAgent.resultsWindow(agent)
   return agent.results_agent:window()
end







function ReviewAgent._init(agent)
   Agent._init(agent)
   agent.selected_index = 0
   agent.edit_agents = {}
   agent.results_agent = ResultsAgent()
   agent.status_cycle_map = {}
   agent.status_reverse_map = {}
   for i, this_status in ipairs(agent.valid_statuses) do
      local prev_status = i == 1
         and agent.valid_statuses[#agent.valid_statuses]
         or agent.valid_statuses[i - 1]
      local next_status = i == #agent.valid_statuses
         and agent.valid_statuses[1]
         or agent.valid_statuses[i + 1]
      agent.status_cycle_map[this_status] = next_status
      agent.status_reverse_map[this_status] = prev_status
   end
end




return core.cluster.constructor(ReviewAgent)

