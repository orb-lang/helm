


local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"




return Keymap({
   ESC = "cancel",
   RETURN = "acceptDefault",
   ["[CHARACTER]"] = { method = "letterShortcut", n = 1 }
},
parts.global_commands
)

