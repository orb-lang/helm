


local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"




return Keymap({
   target = "agents.modal",
   bindings = {
      ESC = "cancel",
      RETURN = "acceptDefault",
      ["[CHARACTER]"] = { method = "letterShortcut", n = 1 }
   }
}, {
   target = "modeS",
   bindings = parts.global_commands
})

