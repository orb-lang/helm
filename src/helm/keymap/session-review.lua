


local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"




return Keymap(parts.review_common,
{
   a = { method = "setSelectedState", "accept"},
   r = { method = "setSelectedState", "reject"},
   i = { method = "setSelectedState", "ignore"},
   t = { method = "setSelectedState", "trash"},
   RETURN = "editSelectedTitle",
   ["C-q"] = "promptSaveChanges"
},
parts.set_targets("agents.session.results_agent", parts.cursor_scrolling),
parts.global_commands)

