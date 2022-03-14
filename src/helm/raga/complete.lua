




local table = core.table
local clone, splice = assert(table.clone), assert(table.splice)
local EditBase = require "helm/raga/edit"

local Complete = clone(EditBase, 2)

Complete.name = "complete"
Complete.prompt_char = "💬"






Complete.default_keymaps = {
   { source = "agents.suggest", name = "keymap_selection" },
   { source = "agents.suggest", name = "keymap_actions"}
}
splice(Complete.default_keymaps, EditBase.default_keymaps)










function Complete.onTxtbufChanged(modeS)
   modeS:agent'suggest':update()
   if modeS:agent'suggest'.last_collection then
      modeS:agent'suggest':selectFirst()
   else
      modeS:shiftMode("default")
   end
   EditBase.onTxtbufChanged(modeS)
end










function Complete.onCursorChanged(modeS)
   modeS:shiftMode("default")
   EditBase.onCursorChanged(modeS)
end









local Point = require "anterm:point"
function Complete.getCursorPosition(modeS)
   local point = EditBase.getCursorPosition(modeS)
   local suggestion = modeS:agent'suggest'.last_collection:selectedItem()
   if suggestion then
      for _, tok in ipairs(modeS:agent'edit':tokens()) do
         if tok.cursor_offset then
            point = point + Point(0, #suggestion - tok.cursor_offset)
            break
         end
      end
   end
   return point
end








function Complete.onShift(modeS)
   modeS:agent'suggest':selectFirst()
end








function Complete.onUnshift(modeS)
   modeS:agent'suggest':selectNone()
end



return Complete

