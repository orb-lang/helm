


local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"




return Keymap(
parts.set_targets("agents.run_review", {
   RETURN = "acceptInsertion",
   ESC = "cancelInsertEditing",
   ["C-q"] = "cancelInsertEditing"
}),
parts.basic_editing,
parts.global_commands)

