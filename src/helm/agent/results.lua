








local cluster = require "cluster:cluster"
local Agent = require "helm:agent/agent"






local new, ResultsAgent = cluster.genus(Agent)
cluster.extendbuilder(new, true)






function ResultsAgent.update(agent, result)
   agent.result = result
   agent:contentsChanged()
   agent:scrollToTop()
end

function ResultsAgent.clear(agent)
   agent:update(nil)
end






function ResultsAgent.bufferValue(agent)
   return agent.result or { n = 0 }
end









function ResultsAgent.clearOnFirstKey(agent)
   if agent :send { to = "agents.edit", method = "isEmpty" } then
      agent:clear()
   end
   return false
end




return new

