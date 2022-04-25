


local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"



local advanced_scrolling = {}
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
      advanced_scrolling[shortcut] = cmd
   end
end



return Keymap({
   target = "agents.pager",
   bindings = {
      ESC = "quit",
      q = "quit"
   }
}, {
   target = "agents.pager",
   bindings = advanced_scrolling
}, {
   target = "modeS",
   bindings = parts.global_commands
})

