




local SessionAgent = meta {}







function SessionAgent.update(agent, sesh)
   agent.session = sesh
   agent.selected_index = #sesh == 0 and 0 or 1
   agent.touched = true
end











local clamp = assert(require "core:math" . clamp)
function SessionAgent.selectIndex(agent, index)
   index = #agent.session == 0
      and 0
      or clamp(index, 1, #agent.session)
   if index ~= agent.selected_index then
      agent.selected_index = index
      agent.touched = true
      -- #todo can/should we be the ones to update the EditAgent somehow?
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












local function _swapPremises(agent, index_a, index_b)
   local premise_a = agent.session[index_a]
   local premise_b = agent.session[index_b]
   agent.session[index_a] = premise_b
   premise_b.ordinal = index_a
   agent.session[index_b] = premise_a
   premise_a.ordinal = index_b
   agent.touched = true
end

function SessionAgent.movePremiseUp(agent)
   if agent.selected_index == 1 then
      return false
   end
   _swapPremises(agent, agent.selected_index, agent.selected_index - 1)
   -- Maintain selection of the same premise after the move
   -- Will never wrap because we disallowed moving the first premise up
   agent:selectPreviousWrap()
   return true
end

function SessionAgent.movePremiseDown(agent)
   if agent.selected_index == #agent.session then
      return false
   end
   _swapPremises(agent, agent.selected_index, agent.selected_index + 1)
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
   closure = { selectedPremise = true }
})






local function new()
   local agent = meta(SessionAgent)
   agent.selected_index = 0
   return agent
end



SessionAgent.idEst = new
return new

