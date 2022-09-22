








local cluster = require "cluster:cluster"
local Agent = require "helm:agent/agent"






local new, PromptAgent = cluster.genus(Agent)
cluster.extendbuilder(new, true)






function PromptAgent.update(agent, prompt_char)
   agent.prompt_char = prompt_char
   agent:contentsChanged()
end










function PromptAgent.checkTouched(agent)
   -- #todo .touched propagation is weird, we can't :checkTouched()
   -- on the EditAgent because we'll clear stuff prematurely
   -- All of this should be replaced by a handler for an action sent
   -- by the EditAgent (which would replace onTxtbufChanged() as well)
   agent.touched = agent.touched or agent :send { to = "agents.edit", field = "touched" }
   return Agent.checkTouched(agent)
end






function PromptAgent.bufferValue(agent)
   local continuation_lines = agent :send { to = "agents.edit",
                                          method = "continuationLines" }
   return agent.prompt_char .. " " .. ("\n..."):rep(continuation_lines)
end




return new

