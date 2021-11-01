








local SelectionList = require "helm:selection_list"
local yield = assert(coroutine.yield)




local meta = assert(require "core:cluster" . Meta)
local Agent = require "helm:agent/agent"
local ResultListAgent = meta(getmetatable(Agent))









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
   yield{ method = "shiftMode", n = 1, "default" }
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














ResultListAgent.keymap_selection = {
   TAB = "selectNextWrap",
   DOWN = "selectNextWrap",
   ["S-DOWN"] = "selectNextWrap",
   ["S-TAB"] = "selectPreviousWrap",
   UP = "selectPreviousWrap",
   ["S-UP"] = "selectPreviousWrap"
}

-- These are both abstract methods
ResultListAgent.keymap_actions = {
   RETURN = "acceptSelected",
   ESC = "userCancel"
}




local constructor = assert(require "core:cluster" . constructor)
return constructor(ResultListAgent)

