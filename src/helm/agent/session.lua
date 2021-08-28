







local EditAgent = require "helm:agent/edit"
local ResultsAgent = require "helm:agent/results"




local SessionAgent = meta {}









local function _update_edit_agent(agent, index)
   local edit_agent = agent.edit_agents[index]
   if edit_agent then
      edit_agent:update(agent.session[index].line)
   end
end

local function _update_results_agent(agent)
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






function SessionAgent.update(agent, sesh)
   agent.session = sesh
   agent.selected_index = #sesh == 0 and 0 or 1
   _update_results_agent(agent)
   -- Update any EditAgents we have without creating any more
   for index in pairs(agent.edit_agents) do
      _update_edit_agent(agent, index)
   end
   agent.touched = true
end











local clamp = assert(require "core:math" . clamp)
function SessionAgent.selectIndex(agent, index)
   index = #agent.session == 0
      and 0
      or clamp(index, 1, #agent.session)
   if index ~= agent.selected_index then
      agent.selected_index = index
      _update_results_agent(agent)
      agent.touched = true
      -- #todo can/should we be the ones to update the EditAgent
      -- for the title somehow?
   end
end









function SessionAgent.selectNextWrap(agent)
   local new_idx = agent.selected_index < #agent.session
      and agent.selected_index + 1
      or 1
   return agent:selectIndex(new_idx)
end
function SessionAgent.selectPreviousWrap(agent)
   local new_idx = agent.selected_index > 1
      and agent.selected_index - 1
      or #agent.session
   return agent:selectIndex(new_idx)
end






function SessionAgent.selectedPremise(agent)
   return agent.session[agent.selected_index]
end












local status_cycle_map = {
   ignore = "accept",
   accept = "reject",
   reject = "skip",
   skip   = "ignore"
}

function SessionAgent.toggleSelectedState(agent)
   local premise = agent:selectedPremise()
   premise.status = status_cycle_map[premise.status]
   agent.touched = true
   return true
end

local inverse = assert(require "core:table" . inverse)
local status_reverse_map = inverse(status_cycle_map)

function SessionAgent.reverseToggleSelectedState(agent)
   local premise = agent:selectedPremise()
   premise.status = status_reverse_map[premise.status]
   agent.touched = true
   return true
end












local function _swap_premises(agent, index_a, index_b)
   local premise_a = agent.session[index_a]
   local premise_b = agent.session[index_b]

   agent.session[index_a] = premise_b
   premise_b.ordinal = index_a
   _update_edit_agent(agent, index_a)

   agent.session[index_b] = premise_a
   premise_a.ordinal = index_b
   _update_edit_agent(agent, index_b)

   agent.touched = true
end

function SessionAgent.movePremiseUp(agent)
   if agent.selected_index == 1 then
      return false
   end
   _swap_premises(agent, agent.selected_index, agent.selected_index - 1)
   -- Maintain selection of the same premise after the move
   -- Will never wrap because we disallowed moving the first premise up
   agent:selectPreviousWrap()
   return true
end

function SessionAgent.movePremiseDown(agent)
   if agent.selected_index == #agent.session then
      return false
   end
   _swap_premises(agent, agent.selected_index, agent.selected_index + 1)
   agent:selectNextWrap()
   return true
end









local agent_utils = require "helm:agent/utils"

SessionAgent.checkTouched = agent_utils.checkTouched

SessionAgent.window = agent_utils.make_window_method({
   field = { selected_index = true },
   fn = {
      buffer_value = function(agent, window, field)
         return agent.session
      end
   },
   closure = { selectedPremise = true,
               editWindow = true,
               resultsWindow = true }
})








local inbounds = assert(require "core:math" . inbounds)
local lua_thor = assert(require "helm:lex" . lua_thor)
function SessionAgent.editWindow(agent, index)
   assert(inbounds(index, 1, #agent.session))
   if not agent.edit_agents[index] then
      agent.edit_agents[index] = EditAgent()
      agent.edit_agents[index].lex = lua_thor
      _update_edit_agent(agent, index)
   end
   return agent.edit_agents[index]:window()
end










function SessionAgent.resultsWindow(agent)
   if not agent.results_agent then
      agent.results_agent = ResultsAgent()
      _update_results_agent(agent)
   end
   return agent.results_agent:window()
end






local function new()
   local agent = meta(SessionAgent)
   agent.selected_index = 0
   agent.edit_agents = {}
   return agent
end



SessionAgent.idEst = new
return new
