






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









function ResultsAgent.clearOnFirstKey(agent)
   if send { sendto = "agents.edit", method = "isEmpty" } then
      agent:clear()
   end
   return false
end





ResultsAgent.keymap_reset = {
   ["[CHARACTER]"] = "clearOnFirstKey",
   PASTE = "clearOnFirstKey"
}




local constructor = assert(require "core:cluster" . constructor)
return constructor(ResultsAgent)

