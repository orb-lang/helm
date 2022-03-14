







local EditAgent = require "helm:agent/edit"
local ResultsAgent = require "helm:agent/results"

local math = core.math
local table = core.table




local Agent = require "helm:agent/agent"
local SessionAgent = meta(getmetatable(Agent))









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
   agent:contentsChanged()
end











local clamp = assert(math.clamp)
function SessionAgent.selectIndex(agent, index)
   index = #agent.session == 0
      and 0
      or clamp(index, 1, #agent.session)
   if index ~= agent.selected_index then
      agent.selected_index = index
      _update_results_agent(agent)
      agent:contentsChanged()
      agent:bufferCommand("ensureSelectedVisible")
      local premise = agent:selectedPremise()
      agent :send { sendto = "agents.edit",
                    method = "update",
                    premise and premise.title }
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
   local premise_a = agent.session[index_a]
   local premise_b = agent.session[index_b]

   agent.session[index_a] = premise_b
   premise_b.ordinal = index_a
   _update_edit_agent(agent, index_a)

   agent.session[index_b] = premise_a
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
   if agent.selected_index == #agent.session then
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
   local new_title = agent :send { sendto = "agents.edit", method = "contents" }
   agent:selectedPremise().title = new_title
   agent:selectNextWrap()
   agent:cancelTitleEditing()
end






SessionAgent.keymap_edit_title = {
   RETURN = "acceptTitleUpdate",
   TAB = "acceptTitleUpdate",
   ESC = "cancelTitleEditing",
   ["C-q"] = "acceptTitleUpdate"
}









function SessionAgent.bufferValue(agent)
   return agent.session
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
   assert(inbounds(index, 1, #agent.session))
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












SessionAgent.keymap_default = {
   UP = "selectPreviousWrap",
   DOWN = "selectNextWrap",
   TAB = "toggleSelectedState",
   ["S-TAB"] = "reverseToggleSelectedState",
   ["M-UP"] = "movePremiseUp",
   ["M-DOWN"] = "movePremiseDown",
   RETURN = "editSelectedTitle"
}






function SessionAgent._init(agent)
   Agent._init(agent)
   agent.selected_index = 0
   agent.edit_agents = {}
   agent.results_agent = ResultsAgent()
end




return core.cluster.constructor(SessionAgent)

