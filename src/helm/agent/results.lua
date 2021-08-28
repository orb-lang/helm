






local ResultsAgent = meta {}






function ResultsAgent.update(agent, result)
   agent.buffer_value = result or { n = 0 }
   agent.touched = true
end

function ResultsAgent.clear(agent)
   agent:update(nil)
end






local agent_utils = require "helm:agent/utils"

ResultsAgent.checkTouched = agent_utils.checkTouched

ResultsAgent.window = agent_utils.make_window_method({
   field = { buffer_value = true }
})






local function new()
   local agent = meta(ResultsAgent)
   agent.buffer_value = { n = 0 }
   return agent
end



ResultsAgent.idEst = new
return new
