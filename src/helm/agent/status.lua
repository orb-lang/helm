





local StatusAgent = meta {}






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





local agent_utils = require "helm:agent/utils"
StatusAgent.checkTouched = assert(agent_utils.checkTouched)

local Window = require "window:window"
StatusAgent.window = agent_utils.make_window_method({
   fn = { buffer_value = function(stat, window, field)
      return status_lines[stat.status_name]:format(unpack(stat.format_args))
   end }
})





local function new()
   local stat = meta(StatusAgent)
   stat.status_name = 'default'
   stat.format_args = { n = 0 }
   return stat
end



StatusAgent.idEst = new
return new
