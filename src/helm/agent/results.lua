






local meta = assert(require "core:cluster" . Meta)
local Agent = require "helm:agent/agent"
local ResultsAgent = meta(getmetatable(Agent))






function ResultsAgent.update(agent, result)
   agent.result = result
   agent.touched = true
end

function ResultsAgent.clear(agent)
   agent:update(nil)
end






function ResultsAgent.bufferValue(agent)
   return agent.result or { n = 0 }
end




local ResultsAgent_class = setmetatable({}, ResultsAgent)
ResultsAgent.idEst = ResultsAgent_class

return ResultsAgent_class

