






local cluster = require "cluster:cluster"
local Agent = require "helm:agent/agent"






local new, PagerAgent = cluster.genus(Agent)
cluster.extendbuilder(new, true)






function PagerAgent.update(agent, str)
   agent.str = str
   agent:contentsChanged()
end

function PagerAgent.clear(agent)
   agent:update(nil)
end








function PagerAgent.activate(agent)
   agent :send { method = "pushMode", "page" }
end
function PagerAgent.quit(agent)
   agent :send { method = "popMode" }
end






function PagerAgent.bufferValue(agent)
   -- #todo we should work with a Rainbuf that does word-aware wrapping
   -- and accepts a string directly, rather than abusing Resbuf
   return { n = 1, agent.str }
end




return new

