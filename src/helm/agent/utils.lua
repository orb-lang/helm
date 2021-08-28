





local agent_utils = {}








function agent_utils.checkTouched(agent)
   local touched = agent.touched
   agent.touched = false
   return touched
end














local addall = assert(require "core:table" . addall)
local function make_window_cfg(more_cfg)
   local cfg = {
      field = { touched = true },
      closure = { checkTouched = true }
   }
   for cat, props in pairs(more_cfg) do
      cfg[cat] = cfg[cat] or {}
      addall(cfg[cat], props)
   end
   return cfg
end









local Window = require "window:window"

function agent_utils.make_window_method(more_cfg)
   local window_cfg = make_window_cfg(more_cfg)
   return function(agent)
      -- #todo is it reasonable for Agents to cache their window like this?
      -- Is it reasonable for others to *assume* that they will (if it even matters)?
      agent._window = agent._window or Window(agent, window_cfg)
      return agent._window
   end
end



return agent_utils
