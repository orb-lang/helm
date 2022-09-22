










local cluster = require "cluster:cluster"
local Actor = require "actor:actor"

local Window = require "window:window"
local Deque = require "deque:deque"
local Message = require "actor:message"

local table = core.table









local new, Agent, Agent_M = cluster.genus(Actor)

cluster.extendbuilder(new, function(_new, agent)
   agent.buffer_commands = Deque()
   return agent
end)








function Agent.checkTouched(agent)
   local touched = agent.touched
   agent.touched = false
   return touched
end








function Agent.bufferCommand(agent, name, ...)
   local msg = pack(...)
   msg.method = name
   agent.buffer_commands:push(msg)
end










function Agent.contentsChanged(agent)
   agent.touched = true -- #deprecated
   agent:bufferCommand("clearCaches")
end
















for _, scroll_fn in ipairs{
   "scrollTo", "scrollBy",
   "scrollUp", "scrollDown",
   "pageUp", "pageDown",
   "halfPageUp", "halfPageDown",
   "scrollToTop", "scrollToBottom",
   "ensureVisible"
} do
   Agent[scroll_fn] = function(agent, ...)
      agent:bufferCommand(scroll_fn, ...)
   end
end









function Agent.evtScrollUp(agent, evt)
   agent:scrollUp(evt.num_lines)
end
function Agent.evtScrollDown(agent, evt)
   agent:scrollDown(evt.num_lines)
end












local addall = assert(table.addall)
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
      fn = {
         buffer_value = function(agent, window, field)
            return agent:bufferValue()
         end,
         commands = function(agent, window, field)
            return agent.buffer_commands
         end
      },
      closure = { checkTouched = true }
   }
end

function Agent.window(agent)
   return Window(agent, agent:windowConfiguration())
end




return new

