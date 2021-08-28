






local PromptAgent = meta {}






function PromptAgent.update(agent, prompt_char)
   agent.prompt_char = prompt_char
   agent.touched = true
end










local agent_utils = require "helm:agent/utils"

function PromptAgent.checkTouched(agent)
   -- #todo .touched propagation is weird, we can't :checkTouched()
   -- on the EditAgent because we'll clear stuff prematurely
   agent.touched = agent.touched or agent.editTouched()
   return agent_utils.checkTouched(agent)
end





PromptAgent.window = agent_utils.make_window_method({
   fn = { buffer_value = function(agent, window, field)
      return agent.prompt_char .. " " ..
                ("\n..."):rep(agent.continuationLines())
   end}
})






local function new()
   local agent = meta(PromptAgent)
   return agent
end



PromptAgent.idEst = new
return new
