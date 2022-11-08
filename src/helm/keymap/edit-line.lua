


local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"




return Keymap(
parts.set_targets("agents.run_review", {
   RETURN = "acceptLineEdit",
   ESC = "cancelLineEdit",
   ["C-q"] = "cancelLineEdit"
}),
parts.set_targets("agents.suggest", {
   TAB = "activateCompletion",
   ["S-TAB"] = "activateCompletion"
}),
parts.basic_editing,
parts.global_commands)

