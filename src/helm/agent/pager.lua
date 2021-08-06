






local meta = assert(require "core:cluster" . Meta)
local Agent = require "helm:agent/agent"
local PagerAgent = meta(getmetatable(Agent))






function PagerAgent.update(agent, str)
   agent.str = str
   agent.touched = true
end

function PagerAgent.clear(agent)
   agent:update(nil)
end






function PagerAgent.bufferValue(agent)
   -- #todo we should work with a Rainbuf that does word-aware wrapping
   -- and accepts a string directly, rather than abusing Resbuf
   return { n = 1, agent.str }
end




local constructor = assert(require "core:cluster" . constructor)
return constructor(PagerAgent)

