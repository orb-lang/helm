





local addall, clone = import("core/table", "addall", "clone")
local RagaBase = require "helm:helm/raga/base"
local Txtbuf = require "helm/txtbuf"



local EditBase = clone(RagaBase, 2)









local function toTxtbuf(fn)
   return function(modeS, category, value)
      return modeS.txtbuf[fn](modeS.txtbuf)
   end
end






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







local NAV = EditBase.NAV
addall(NAV, {
   LEFT           = toTxtbuf "left",
   RIGHT          = toTxtbuf "right",
   ALT_LEFT       = toTxtbuf "leftWordAlpha",
   ALT_RIGHT      = toTxtbuf "rightWordAlpha",
   HOME           = toTxtbuf "startOfLine",
   END            = toTxtbuf "endOfLine",
   BACKSPACE      = toTxtbuf "killBackward",
   DELETE         = toTxtbuf "killForward",
   ALT_BACKSPACE  = toTxtbuf "killToBeginningOfWord",
   ALT_DELETE     = toTxtbuf "killToEndOfWord",
})







local CTRL = EditBase.CTRL

CTRL ["^A"] = NAV.HOME
CTRL ["^E"] = NAV.END

local function clear_txtbuf(modeS, category, value)
   modeS:setTxtbuf(Txtbuf())
   modeS:setResults("")
   modeS.hist.cursor = modeS.hist.n + 1
end

CTRL ["^L"] = clear_txtbuf

CTRL ["^R"] = function(modeS, category, value)
                 modeS:restart()
              end

CTRL ["^K"] = toTxtbuf "killToEndOfLine"
CTRL ["^U"] = toTxtbuf "killToBeginningOfLine"
CTRL ["^T"] = toTxtbuf "transposeLetter"






addall(EditBase.ALT, {
   ["M-w"] = NAV.ALT_RIGHT,
   ["M-b"] = NAV.ALT_LEFT,
   ["M-d"] = NAV.ALT_DELETE
})



return EditBase
