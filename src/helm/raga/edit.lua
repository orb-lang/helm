





local clone = import("core/table", "clone")
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

NAV.LEFT        = toTxtbuf "left"
NAV.RIGHT       = toTxtbuf "right"
NAV.ALT_LEFT    = toTxtbuf "leftWordAlpha"
NAV.ALT_RIGHT   = toTxtbuf "rightWordAlpha"
NAV.HOME        = toTxtbuf "startOfLine"
NAV.END         = toTxtbuf "endOfLine"
NAV.BACKSPACE   = toTxtbuf "deleteBackward"
NAV.DELETE      = toTxtbuf "deleteForward"






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






EditBase.ALT ["M-w"] = NAV.ALT_RIGHT

EditBase.ALT ["M-b"] = NAV.ALT_LEFT



return EditBase
