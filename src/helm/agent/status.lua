







local cluster = require "cluster:cluster"
local Agent = require "helm:agent/agent"






local new, StatusAgent = cluster.genus(Agent)

cluster.extendbuilder(new, function(_new, agent)
   agent.topic = { name = 'default', n = 0 }
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
   stat.topic = pack(...)
   stat.topic.name = status_name
   stat:contentsChanged()
end






function StatusAgent.bufferValue(stat)
   return status_lines[stat.topic.name]:format(unpack(stat.topic))
end




return new

