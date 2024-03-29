




local meta = assert(require "core:cluster" . Meta)
local Agent = require "helm:agent/agent"
local PagerAgent = meta(getmetatable(Agent))






function PagerAgent.update(agent, str)
   agent.str = str
   agent:contentsChanged()
end

function PagerAgent.clear(agent)
   agent:update(nil)
end








function PagerAgent.activate(agent)
   agent:shiftMode("page")
end
function PagerAgent.quit(agent)
   agent:shiftMode("default")
end






function PagerAgent.bufferValue(agent)
   -- #todo we should work with a Rainbuf that does word-aware wrapping
   -- and accepts a string directly, rather than abusing Resbuf
   return { n = 1, agent.str }
end






PagerAgent.keymap_actions = {
   ESC = "quit",
   q = "quit"
}

local clone = assert(require "core:table" . clone)
PagerAgent.keymap_scrolling = clone(Agent.keymap_scrolling)
for cmd, shortcuts in pairs{
   scrollDown     = { "RETURN", "e", "j", "C-n", "C-e", "C-j" },
   scrollUp       = { "S-RETURN", "y", "k", "C-y", "C-p", "C-l" },
   pageDown       = { " ", "f", "C-v", "C-f" },
   pageUp         = { "b", "C-b" },
   halfPageDown   = { "d", "C-d" },
   halfPageUp     = { "u", "C-u" },
   scrollToBottom = { "G", ">" },
   scrollToTop    = { "g", "<" }
} do
   for _, shortcut in ipairs(shortcuts) do
      PagerAgent.keymap_scrolling[shortcut] = cmd
   end
end




local constructor = assert(require "core:cluster" . constructor)
return constructor(PagerAgent)

