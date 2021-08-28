






local PagerAgent = meta {}






function PagerAgent.update(agent, str)
   agent.str = str
   agent.touched = true
end

function PagerAgent.clear(agent)
   agent:update(nil)
end






local agent_utils = require "helm:agent/utils"

PagerAgent.checkTouched = agent_utils.checkTouched

PagerAgent.window = agent_utils.make_window_method({
   fn = { buffer_value = function(agent, window, field)
      -- #todo we should work with a Rainbuf that does word-aware wrapping
      -- and accepts a string directly, rather than abusing Resbuf
      return { n = 1, agent.str }
   end }
})






local function new()
   return meta(PagerAgent)
end



PagerAgent.idEst = new
return new
