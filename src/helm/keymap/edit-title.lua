


local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"




return Keymap({
   target = "agents.session",
   bindings = {
      RETURN = "acceptTitleUpdate",
      TAB = "acceptTitleUpdate",
      ESC = "cancelTitleEditing",
      ["C-q"] = "acceptTitleUpdate"
   }
}, {
   target = "agents.edit",
   bindings = parts.basic_editing
}, {
   target = "modeS",
   bindings = parts.global_commands
})

