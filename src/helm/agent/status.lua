







local cluster = require "cluster:cluster"
local Agent = require "helm:agent/agent"






local new, StatusAgent = cluster.genus(Agent)

cluster.extendbuilder(new, function(_new, agent)
   agent.status_name = 'default'
   agent.format_args = { n = 0 }
   return agent
end)









local status_lines = {
   default            = "an repl, plz reply uwu 👀",
   quit               = "exiting repl, owo... 🐲",
   restart            = "restarting an repl ↩️",
   session_review     = 'reviewing session "%s"',
   run_review_initial = 'Press Return to Evaluate, Tab/Up/Down to Edit',
   run_review         = 'Press M-e to Evaluate' }
status_lines.new_session = status_lines.default .. ' (recording "%s")'










function StatusAgent.update(stat, status_name, ...)
   stat.status_name = status_name
   stat.format_args = pack(...)
   stat:contentsChanged()
end






function StatusAgent.bufferValue(stat)
   return status_lines[stat.status_name]:format(unpack(stat.format_args))
end




return new

