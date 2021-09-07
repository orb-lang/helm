






local meta = assert(require "core:cluster" . Meta)
local Agent = require "helm:agent/agent"
local PromptAgent = meta(getmetatable(Agent))






function PromptAgent.update(agent, prompt_char)
   agent.prompt_char = prompt_char
   agent:contentsChanged()
end










function PromptAgent.checkTouched(agent)
   -- #todo .touched propagation is weird, we can't :checkTouched()
   -- on the EditAgent because we'll clear stuff prematurely
   agent.touched = agent.touched or agent.editTouched()
   return Agent.checkTouched(agent)
end






function PromptAgent.bufferValue(agent)
   return agent.prompt_char .. " " .. ("\n..."):rep(agent.continuationLines())
end




local constructor = assert(require "core:cluster" . constructor)
return constructor(PromptAgent)

