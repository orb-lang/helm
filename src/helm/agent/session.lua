







local EditAgent = require "helm:agent/edit"
local ResultsAgent = require "helm:agent/results"

local math = core.math
local table = core.table




local Agent = require "helm:agent/agent"
local SessionAgent = meta(getmetatable(Agent))









local function _update_edit_agent(agent, index)
   local edit_agent = agent.edit_agents[index]
   if edit_agent then
      edit_agent:update(agent.subject[index].line)
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
   agent.subject = sesh
   agent.selected_index = #sesh == 0 and 0 or 1
   _update_results_agent(agent)
   -- Update any EditAgents we have without creating any more
   for index in pairs(agent.edit_agents) do
      _update_edit_agent(agent, index)
   end
   agent:contentsChanged()
end











local clamp = assert(math.clamp)
function SessionAgent.selectIndex(agent, index)
   index = #agent.subject == 0
      and 0
      or clamp(index, 1, #agent.subject)
   if index ~= agent.selected_index then
      agent.selected_index = index
      _update_results_agent(agent)
      agent:contentsChanged()
      agent:bufferCommand("ensureSelectedVisible")
      local premise = agent:selectedPremise()
      agent :send { to = "agents.edit",
                    method = "update",
                    premise and premise.title }
   end
end









function SessionAgent.selectNextWrap(agent)
   local new_idx = agent.selected_index < #agent.subject
      and agent.selected_index + 1
      or 1
   return agent:selectIndex(new_idx)
end
function SessionAgent.selectPreviousWrap(agent)
   local new_idx = agent.selected_index > 1
      and agent.selected_index - 1
      or #agent.subject
   return agent:selectIndex(new_idx)
end






function SessionAgent.selectedPremise(agent)
   return agent.subject[agent.selected_index]
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
   agent:contentsChanged()
   return true
end

local inverse = assert(table.inverse)
local status_reverse_map = inverse(status_cycle_map)

function SessionAgent.reverseToggleSelectedState(agent)
   local premise = agent:selectedPremise()
   premise.status = status_reverse_map[premise.status]
   agent:contentsChanged()
   return true
end












local function _swap_premises(agent, index_a, index_b)
   local premise_a = agent.subject[index_a]
   local premise_b = agent.subject[index_b]

   agent.subject[index_a] = premise_b
   premise_b.ordinal = index_a
   _update_edit_agent(agent, index_a)

   agent.subject[index_b] = premise_a
   premise_a.ordinal = index_b
   _update_edit_agent(agent, index_b)

   agent:contentsChanged()
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
   if agent.selected_index == #agent.subject then
      return false
   end
   _swap_premises(agent, agent.selected_index, agent.selected_index + 1)
   agent:selectNextWrap()
   return true
end










function SessionAgent.editSelectedTitle(agent)
   agent :send { method = "shiftMode", "edit_title" }
end

function SessionAgent.cancelTitleEditing(agent)
   agent :send { method = "shiftMode", "review" }
end








function SessionAgent.acceptTitleUpdate(agent)
   local new_title = agent :send { to = "agents.edit", method = "contents" }
   agent:selectedPremise().title = new_title
   agent:selectNextWrap()
   agent:cancelTitleEditing()
end






function SessionAgent.promptSaveChanges(agent)
   local sesh_title = agent.subject.session_title
   agent:send { to = "agents.modal", method = "show",
      'Save changes to the session "' .. sesh_title .. '"?',
      "yes_no_cancel" }
end









function SessionAgent.bufferValue(agent)
   return agent.subject
end









function SessionAgent.windowConfiguration(agent)
   return agent.mergeWindowConfig(Agent.windowConfiguration(), {
      field = { selected_index = true },
      closure = { selectedPremise = true,
                  editWindow = true,
                  resultsWindow = true }
   })
end








local inbounds = assert(math.inbounds)
local lua_thor = assert(require "helm:lex" . lua_thor)
function SessionAgent.editWindow(agent, index)
   assert(inbounds(index, 1, #agent.subject))
   if not agent.edit_agents[index] then
      agent.edit_agents[index] = EditAgent()
      agent.edit_agents[index].lex = lua_thor
      _update_edit_agent(agent, index)
   end
   return agent.edit_agents[index]:window()
end










function SessionAgent.resultsWindow(agent)
   return agent.results_agent:window()
end






function SessionAgent._init(agent)
   Agent._init(agent)
   agent.selected_index = 0
   agent.edit_agents = {}
   agent.results_agent = ResultsAgent()
end




return core.cluster.constructor(SessionAgent)

