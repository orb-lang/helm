




local clone = import("core/table", "clone")
local EditBase = require "helm/raga/edit"

local Complete = clone(EditBase, 2)

Complete.name = "complete"
Complete.prompt_char = "👉"






local function _quit(modeS)
   modeS.suggest:cancel(modeS)
   -- #todo restore last-used raga instead of always returning to default
   modeS.shift_to = modeS.raga_default
end

local function _accept(modeS)
   modeS.suggest:accept(modeS)
   _quit(modeS)
end

function Complete.PASTE(modeS, category, value)
   _quit(modeS)
   modeS.action_complete = false
end




local find = assert(string.find)
local function _insert(modeS, category, value)
   -- Non-symbol character accepts the completion
   -- #todo should be consistent with lex.orb definition
   if find(value, "[^a-zA-Z0-9_]") then
      _accept(modeS, category, value)
      modeS.action_complete = false
   else
      EditBase(modeS, category, value)
   end
end

Complete.ASCII = _insert
Complete.UTF8 = _insert





local NAV = Complete.NAV

function NAV.TAB(modeS, category, value)
   modeS.suggest.active_suggestions[1]:selectNext()
   modeS.zones.suggest.touched = true
end
NAV.DOWN = NAV.TAB
NAV.SHIFT_DOWN = NAV.TAB

function NAV.SHIFT_TAB(modeS, category, value)
   modeS.suggest.active_suggestions[1]:selectPrevious()
   modeS.zones.suggest.touched = true
end
NAV.UP = NAV.SHIFT_TAB
NAV.SHIFT_UP = NAV.SHIFT_TAB

NAV.ESC = _quit
function NAV.RIGHT(modeS, category, value)
   _quit(modeS, category, value)
   modeS.action_complete = false
end

NAV.RETURN = _accept
function NAV.LEFT(modeS, category, value)
   _accept(modeS, category, value)
   modeS.action_complete = false
end





function Complete.cursorChanged(modeS)
   modeS.suggest:update(modeS)
   EditBase.cursorChanged(modeS)
end



return Complete
