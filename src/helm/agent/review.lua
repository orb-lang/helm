








local core = require "qor:core"
local math = core.math
local assert = assert(core.fn.assertfmt)

local cluster = require "cluster:cluster"
local Agent = require "helm:agent/agent"

local EditAgent = require "helm:agent/edit"
local ResultsAgent = require "helm:agent/results"






local new, ReviewAgent = cluster.genus(Agent)

cluster.extendbuilder(new, function(_new, agent)
   agent.selected_index = 0
   agent.edit_agents = {}
   agent.results_agent = ResultsAgent()
   agent.status_cycle_map = {}
   agent.status_reverse_map = {}
   local stats = _new.valid_statuses
   for i, this_status in ipairs(stats) do
      local prev_status = i == 1
         and stats[#stats]
         or stats[i - 1]
      local next_status = i == #stats
         and stats[1]
         or stats[i + 1]
      agent.status_cycle_map[this_status] = next_status
      agent.status_reverse_map[this_status] = prev_status
   end
   return agent
end)









function ReviewAgent.update(agent, run)
   agent.topic = run
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
      edit_agent:update(agent.topic[index]:getLine())
   end
end

function ReviewAgent._updateResultsAgent(agent)
   local results_agent = agent.results_agent
   if results_agent then
      local round = agent:selectedRound()
      local result = round and round:result()
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
   index = #agent.topic == 0
      and 0
      or clamp(index, 1, #agent.topic)
   if index ~= agent.selected_index then
      agent.selected_index = index
      agent:selectionChanged()
   end
end









function ReviewAgent.selectNextWrap(agent)
   local new_idx = agent.selected_index < #agent.topic
      and agent.selected_index + 1
      or 1
   return agent:selectIndex(new_idx)
end
function ReviewAgent.selectPreviousWrap(agent)
   local new_idx = agent.selected_index > 1
      and agent.selected_index - 1
      or #agent.topic
   return agent:selectIndex(new_idx)
end






function ReviewAgent.selectedRound(agent)
   return agent.topic[agent.selected_index]
end

















function ReviewAgent.toggleSelectedState(agent)
   local new_status = agent.status_cycle_map[agent:selectedRound().status]
   return agent:setSelectedState(new_status)
end

function ReviewAgent.reverseToggleSelectedState(agent)
   local new_status = agent.status_reverse_map[agent:selectedRound().status]
   return agent:setSelectedState(new_status)
end








function ReviewAgent.setSelectedState(agent, state)
   local round = agent:selectedRound()
   if round.status == state then return end
   assert(agent.status_cycle_map[state], "Cannot change to invalid status %s", state)
   round.status = state
   agent:contentsChanged()
   return true
end












local function _swap_rounds(agent, index_a, index_b)
   local round_a = agent.topic[index_a]
   local round_b = agent.topic[index_b]

   agent.topic[index_a] = round_b
   round_b.ordinal = index_a
   agent:_updateEditAgent(index_a)

   agent.topic[index_b] = round_a
   round_a.ordinal = index_b
   agent:_updateEditAgent(index_b)

   agent:contentsChanged()
end

function ReviewAgent.moveRoundUp(agent)
   if agent.selected_index == 1 then
      return false
   end
   _swap_rounds(agent, agent.selected_index, agent.selected_index - 1)
   -- Maintain selection of the same round after the move
   -- Will never wrap because we disallowed moving the first round up
   agent:selectPreviousWrap()
   return true
end

function ReviewAgent.moveRoundDown(agent)
   if agent.selected_index == #agent.topic then
      return false
   end
   _swap_rounds(agent, agent.selected_index, agent.selected_index + 1)
   agent:selectNextWrap()
   return true
end









function ReviewAgent.bufferValue(agent)
   return agent.topic
end









function ReviewAgent.windowConfiguration(agent)
   return agent.mergeWindowConfig(Agent.windowConfiguration(), {
      field = { selected_index = true },
      closure = { selectedRound = true,
                  editWindow = true,
                  resultsWindow = true }
   })
end








local inbounds = assert(math.inbounds)
local lua_thor = assert(require "helm:lex" . lua_thor)
function ReviewAgent.editWindow(agent, index)
   assert(inbounds(index, 1, #agent.topic))
   if not agent.edit_agents[index] then
      -- Stuff not-yet-initialized slots with `false`
      -- to maintain correct insert/remove/etc behavior
      for i = #agent.edit_agents + 1, index - 1 do
         agent.edit_agents[i] = false
      end
      agent.edit_agents[index] = EditAgent()
      agent.edit_agents[index].lex = lua_thor
      agent:_updateEditAgent(index)
   end
   return agent.edit_agents[index]:window()
end










function ReviewAgent.resultsWindow(agent)
   return agent.results_agent:window()
end




return new

