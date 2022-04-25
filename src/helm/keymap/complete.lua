


local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"




return Keymap(
parts.list_selection,
{
      RETURN          = "acceptSelected",
      ESC             = "userCancel",
      LEFT            = "acceptAndFallthrough",
      PASTE           = "quitAndFallthrough",
      ["[CHARACTER]"] = { method = "acceptOnNonWordChar", n = 1 }
},
parts.global_commands
)

