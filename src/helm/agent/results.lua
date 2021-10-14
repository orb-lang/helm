






local meta = assert(require "core:cluster" . Meta)
local Agent = require "helm:agent/agent"
local ResultsAgent = meta(getmetatable(Agent))






function ResultsAgent.update(agent, result)
   agent.result = result
   agent:contentsChanged()
end

function ResultsAgent.clear(agent)
   agent:update(nil)
end






function ResultsAgent.bufferValue(agent)
   return agent.result or { n = 0 }
end






ResultsAgent.keymap_scrolling = {
   SCROLL_UP = { method = "evtScrollUp", n = 1 },
   SCROLL_DOWN = { method = "evtScrollDown", n = 1 },
   ["S-UP"] = { method = "evtScrollUp", n = 1 },
   ["S-DOWN"] = { method = "evtScrollDown", n = 1 }
}




local constructor = assert(require "core:cluster" . constructor)
return constructor(ResultsAgent)

