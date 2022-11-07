








local cluster = require "cluster:cluster"
local Agent = require "helm:agent/agent"

local SelectionList = require "helm:selection_list"






local new, ResultListAgent = cluster.genus(Agent)
cluster.extendbuilder(new, function(_new, agent)
   agent.topic = SelectionList('')
   return agent
end)









for _, method_name in ipairs{"selectNext", "selectPrevious",
                    "selectNextWrap", "selectPreviousWrap",
                    "selectFirst", "selectIndex", "selectNone"} do
   ResultListAgent[method_name] = function(agent, ...)
      agent.topic[method_name](agent.topic, ...)
      agent:contentsChanged()
      agent:bufferCommand("ensureVisible", agent.topic.selected_index)
   end
end





function ResultListAgent.selectedItem(agent)
   return agent.topic:selectedItem()
end






function ResultListAgent.hasResults(agent)
   return #agent.topic > 0
end








function ResultListAgent.quit(agent)
   agent:selectNone()
   agent :send { method = "popMode" }
end






function ResultListAgent.bufferValue(agent)
   return { n = 1, agent.topic }
end






local function _toTopic(agent, window, field, ...)
   return agent.topic[field](agent.topic, ...) -- i.e. topic:<field>(...)
end

function ResultListAgent.windowConfiguration(agent)
   -- #todo super is hella broken, grab explicitly from the right superclass
   return agent.mergeWindowConfig(Agent.windowConfiguration(agent), {
      closure = {
         selectedItem = _toTopic,
         highlight = _toTopic
      }
   })
end




return new

