










local Window = require "window:window"
-- local Deque = require "deque:deque"




local meta = assert(require "core:cluster" . Meta)
local Agent = meta {}






function Agent.checkTouched(agent)
   local touched = agent.touched
   agent.touched = false
   return touched
end


















local addall = assert(require "core:table" . addall)
function Agent.mergeWindowConfig(cfg_a, cfg_b)
   for cat, props in pairs(cfg_b) do
      cfg_a[cat] = cfg_a[cat] or {}
      addall(cfg_a[cat], props)
   end
   return cfg_a
end

function Agent.windowConfiguration(agent)
   return {
      field = { touched = true },
      fn = { buffer_value = function(agent, window, field)
         return agent:bufferValue()
      end },
      closure = { checkTouched = true }
   }
end

function Agent.window(agent)
   return Window(agent, agent:windowConfiguration())
end











function Agent._init(agent)
   return
end

function Agent.__call(agent_class)
   local agent_M = getmetatable(agent_class)
   local agent = setmetatable({}, agent_M)
   agent:_init()
   return agent
end




local Agent_class = setmetatable({}, Agent)
Agent.idEst = Agent_class

return Agent_class

