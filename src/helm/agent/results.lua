






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




local constructor = assert(require "core:cluster" . constructor)
return constructor(ResultsAgent)

