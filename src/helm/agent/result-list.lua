








local cluster = require "cluster:cluster"
local Agent = require "helm:agent/agent"

local SelectionList = require "helm:selection_list"






local new, ResultListAgent = cluster.genus(Agent)
cluster.extendbuilder(new, true)









for _, method_name in ipairs{"selectNext", "selectPrevious",
                    "selectNextWrap", "selectPreviousWrap",
                    "selectFirst", "selectIndex", "selectNone"} do
   ResultListAgent[method_name] = function(agent, ...)
      if agent.last_collection then
         agent.last_collection[method_name](agent.last_collection, ...)
         agent:contentsChanged()
         agent:bufferCommand("ensureVisible", agent.last_collection.selected_index)
      end
   end
end





function ResultListAgent.selectedItem(agent)
   return agent.last_collection and agent.last_collection:selectedItem()
end








function ResultListAgent.quit(agent)
   agent:selectNone()
   agent :send { method = "popMode" }
end






function ResultListAgent.bufferValue(agent)
   return agent.last_collection and { n = 1, agent.last_collection }
end






local function _toLastCollection(agent, window, field, ...)
   local lc = agent.last_collection
   return lc and lc[field](lc, ...) -- i.e. lc:<field>(...)
end

function ResultListAgent.windowConfiguration(agent)
   -- #todo super is hella broken, grab explicitly from the right superclass
   return agent.mergeWindowConfig(Agent.windowConfiguration(agent), {
      closure = {
         selectedItem = _toLastCollection,
         highlight = _toLastCollection
      }
   })
end




return new

