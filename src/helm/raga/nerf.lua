















local concat, insert = assert(table.concat), assert(table.insert)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)
local yield = assert(coroutine.yield)






local core_table = require "core:table"
local addall, clone, splice = assert(core_table.addall),
                              assert(core_table.clone),
                              assert(core_table.splice)
local EditBase = require "helm:helm/raga/edit"

local Nerf = clone(EditBase, 2)
Nerf.name = "nerf"
Nerf.prompt_char = "👉"








function Nerf.historianMessage(method_name, ...)
   local msg = pack(...)
   msg.sendto = "hist"
   msg.method = method_name
   return yield(msg)
end





function Nerf.eval()
   local line = Nerf.agentMessage("edit", "contents")
   local success, results = yield{ call = "eval", n = 1, line }
   if not success and results == 'advance' then
      Nerf.agentMessage("edit", "endOfText")
      return false -- Fall through to EditAgent nl binding
   else
      Nerf.historianMessage("append", line, results, success)
      Nerf.historianMessage("toEnd")
      Nerf.agentMessage("results", "update", results)
      Nerf.agentMessage("edit", "clear")
   end
end

function Nerf.conditionalEval()
   if Nerf.agentMessage("edit", "shouldEvaluate") then
      return Nerf.eval()
   else
      return false -- Fall through to EditAgent nl binding
   end
end

Nerf.keymap_evaluation = {
   RETURN = "conditionalEval",
   ["C-RETURN"] = "eval",
   ["S-RETURN"] = { sendto = "agents.edit", method = "nl" },
   -- Add aliases for terminals not in CSI u mode
   ["C-\\"] = "eval",
   ["M-RETURN"] = { sendto = "agents.edit", method = "nl" }
}






function Nerf.historyBack()
   -- If we're at the end of the history (the user was typing a new
   -- expression), save it before moving
   if Nerf.historianMessage("atEnd") then
      local linestash = Nerf.agentMessage("edit", "contents")
      Nerf.historianMessage("append", linestash)
   end
   local prev_line, prev_result = Nerf.historianMessage("prev")
   Nerf.agentMessage("edit", "update", prev_line)
   Nerf.agentMessage("results", "update", prev_result)
end

function Nerf.historyForward()
   local new_line, next_result = Nerf.historianMessage("next")
   if not new_line then
      local old_line = Nerf.agentMessage("edit", "contents")
      local added = Nerf.historianMessage("append", old_line)
      if added then
         Nerf.historianMessage("toEnd")
      end
   end
   Nerf.agentMessage("edit", "update", new_line)
   Nerf.agentMessage("results", "update", next_result)
end

Nerf.keymap_history_navigation = {
   UP = "historyBack",
   DOWN = "historyForward"
}






function Nerf.evalFromCursor()
   local top = yield{ sendto = "hist", property = "n" }
   local cursor = yield{ sendto = "hist", property = "cursor" }
   for i = cursor, top do
      -- Discard the second return value from :index
      -- or it will confuse the Txtbuf constructor rather badly
      local line = Nerf.historianMessage("index", i)
      Nerf.agentMessage("edit", "update", line)
      Nerf.eval()
   end
end






function Nerf.openHelpOnFirstKey()
   if Nerf.agentMessage("edit", "isEmpty") then
      yield{ method = "openHelp" }
      return true
   else
      return false
   end
end

Nerf.keymap_extra_commands = {
   ["?"] = "openHelpOnFirstKey",
   ["M-e"] = "evalFromCursor"
}
addall(Nerf.keymap_extra_commands, EditBase.keymap_extra_commands)









Nerf.default_keymaps = {
   { source = "agents.search", name = "keymap_try_activate" },
   { source = "agents.suggest", name = "keymap_try_activate" },
   { source = "agents.results", name = "keymap_reset" },






   { source = "modeS.raga", name = "keymap_evaluation" },
   { source = "agents.edit", name = "keymap_readline_nav" }
}





splice(Nerf.default_keymaps, EditBase.default_keymaps)





insert(Nerf.default_keymaps,
       { source = "modeS.raga", name = "keymap_history_navigation" })





insert(Nerf.default_keymaps,
      { source = "agents.results", name = "keymap_scrolling" })









function Nerf.onCursorChanged(modeS)
   modeS:agent'suggest':update()
   EditBase.onCursorChanged(modeS)
end

function Nerf.onTxtbufChanged(modeS)
   modeS:agent'suggest':update()
   EditBase.onTxtbufChanged(modeS)
end










local Resbuf = require "helm:buf/resbuf"
function Nerf.onShift(modeS)
   EditBase.onShift(modeS)
   modeS:bindZone("results", "results", Resbuf, { scrollable = true })
   local txtbuf = modeS.zones.command.contents
   txtbuf.suggestions = modeS:agent'suggest':window()
end



return Nerf

