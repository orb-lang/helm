















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
Nerf.lex = require "helm:lex" . lua_thor









function Nerf.onCursorChanged()
   send { to = "agents.suggest", method = "update" }
   EditBase.onCursorChanged()
end

function Nerf.onTxtbufChanged()
   send { to = "agents.suggest", method = "update" }
   EditBase.onTxtbufChanged()
end










local Resbuf = require "helm:buf/resbuf"
function Nerf.onShift()
   EditBase.onShift()
   -- #todo only if not already a Resbuf?
   send { method = "bindZone",
      "results", "results", Resbuf, { scrollable = true }}
   -- #todo this messing directly with the Txtbuf is bad
   local txtbuf = send { to = "zones.command", field = "contents" }
   txtbuf.suggestions = send { to = "agents.suggest", method = "window" }
end



return Nerf

