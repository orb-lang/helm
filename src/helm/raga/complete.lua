




local table = core.table
local clone, splice = assert(table.clone), assert(table.splice)
local EditBase = require "helm/raga/edit"

local Complete = clone(EditBase, 2)

Complete.name = "complete"
Complete.prompt_char = "💬"
Complete.keymap = require "helm:keymap/complete"
Complete.target = "agents.suggest"












function Complete.onTxtbufChanged()
   send { to = 'agents.suggest', method = 'update' }
   if send { to = 'agents.suggest', field = 'last_collection' } then
      send { to = 'agents.suggest', method = "selectFirst" }
   else
      send { to = "modeS", method = "shiftMode", "default" }
   end
   EditBase.onTxtbufChanged()
end










function Complete.onCursorChanged()
   send { to = "modeS", method = "shiftMode", "default" }
   EditBase.onCursorChanged()
end









local Point = require "anterm:point"
function Complete.getCursorPosition(modeS)
   local point = EditBase.getCursorPosition(modeS)
   local suggestion = send { to = 'agents.suggest', method = 'selectedItem' }
   local tokens = send { to = 'agents.edit', method = 'tokens' }
   if suggestion then
      for _, tok in ipairs(tokens) do
         if tok.cursor_offset then
            point = point + Point(0, #suggestion - tok.cursor_offset)
            break
         end
      end
   end
   return point
end








function Complete.onShift(modeS)
   send { to = 'agents.suggest', method = 'selectFirst' }
end








function Complete.onUnshift(modeS)
   send { to = 'agents.suggest', method = 'selectNone' }
end



return Complete

