


local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"




return Keymap(
parts.set_targets("agents.suggest", parts.list_selection),
parts.set_targets("agents.suggest", {
      RETURN          = "acceptSelected",
      ESC             = "userCancel",
      LEFT            = "acceptAndFallthrough",
      PASTE           = "quitAndFallthrough",
      ["[CHARACTER]"] = { method = "acceptOnNonWordChar", n = 1 }
}),
parts.basic_editing,
parts.global_commands
)

