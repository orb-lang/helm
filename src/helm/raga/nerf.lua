















local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)
local table = core.table
local addall, clone, concat, insert, splice = assert(table.addall),
                                              assert(table.clone),
                                              assert(table.concat),
                                              assert(table.insert),
                                              assert(table.splice)
local s = require "status:status" ()







local EditBase = require "helm:helm/raga/edit"

local Nerf = clone(EditBase, 2)
Nerf.name = "nerf"
Nerf.prompt_char = "👉"
Nerf.keymap = require "helm:keymap/nerf"









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

