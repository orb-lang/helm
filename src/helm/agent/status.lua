





local meta = assert(require "core:cluster" . Meta)
local Agent = require "helm:agent/agent"
local StatusAgent = meta(getmetatable(Agent))






local status_lines = { default = "an repl, plz reply uwu 👀",
                       quit    = "exiting repl, owo... 🐲",
                       restart = "restarting an repl ↩️",
                       review  = 'reviewing session "%s"' }
status_lines.macro       = status_lines.default .. ' (macro-recording "%s")'
status_lines.new_session = status_lines.default .. ' (recording "%s")'










function StatusAgent.update(stat, status_name, ...)
   stat.status_name = status_name
   stat.format_args = pack(...)
   stat.touched = true
end






function StatusAgent.bufferValue(stat)
   return status_lines[stat.status_name]:format(unpack(stat.format_args))
end






function StatusAgent._init(agent)
   Agent._init(agent)
   agent.status_name = 'default'
   agent.format_args = { n = 0 }
end




local StatusAgent_class = setmetatable({}, StatusAgent)
StatusAgent.idEst = StatusAgent_class

return StatusAgent_class

