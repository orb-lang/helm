





local addall, clone = import("core/table", "addall", "clone")
local RagaBase = require "helm:helm/raga/base"
local Txtbuf = require "helm/txtbuf"



local EditBase = clone(RagaBase, 2)












local map = {
   LEFT            = "left",
   RIGHT           = "right",
   ["M-LEFT"]      = "leftWordAlpha",
   ["M-b"]         = "leftWordAlpha",
   ["M-RIGHT"]     = "rightWordAlpha",
   ["M-w"]         = "rightWordAlpha",
   HOME            = "startOfLine",
   ["C-a"]         = "startOfLine",
   END             = "endOfLine",
   ["C-e"]         = "endOfLine",
   BACKSPACE       = "killBackward",
   DELETE          = "killForward",
   ["M-BACKSPACE"] = "killToBeginningOfWord",
   ["M-DELETE"]    = "killToEndOfWord",
   ["M-d"]         = "killToEndOfWord",
   ["C-k"]         = "killToEndOfLine",
   ["C-u"]         = "killToBeginningOfLine",
   ["C-t"]         = "transposeLetter"
}

for key, command in pairs(map) do
   EditBase[command] = function(maestro, event)
      return maestro.modeS.txtbuf[command](modeS.txtbuf)
   end
end

function EditBase.clearTxtbuf(maestro, event)
   maestro.modeS:setTxtbuf(Txtbuf())
   maestro.modeS:setResults("")
   maestro.modeS.hist.cursor = maestro.modeS.hist.n + 1
end
map["C-l"] = "clearTxtbuf"

function EditBase.restartSession(maestro, event)
   maestro.modeS:restart()
end
map["C-r"] = "restartSession"

EditBase.default_keymaps = { map }







local function _insert(modeS, category, value)
   if tostring(modeS.txtbuf) == "" then
      modeS:setResults ""
   end
   modeS.txtbuf:insert(value)
end

EditBase.ASCII = _insert
EditBase.UTF8 = _insert

function EditBase.PASTE(modeS, category, value)
   if tostring(modeS.txtbuf) == "" then
      modeS:setResults ""
   end
   modeS.txtbuf:paste(value)
end









function EditBase.getCursorPosition(modeS)
   return modeS.zones.command.bounds:origin() + modeS.txtbuf.cursor - 1
end




return EditBase

