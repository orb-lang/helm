








local clone = import("core/table", "clone")
local Nerf = require "helm/raga/nerf"

local Complete = clone(Nerf, 3)






local function _quit(modeS, category, value)
   modeS.suggest:cancel(modeS)
   -- #todo restore last-used raga instead of always returning to default
   modeS:shiftMode(modeS.raga_default)
end

local function _accept(modeS, category, value)
   modeS.suggest:accept(modeS)
   _quit(modeS, category, value)
end

function Complete.PASTE(modeS, category, value)
   _quit(modeS, category, value)
   modeS.modes.PASTE(modeS, category, value)
end




local find = assert(string.find)

local _default_insert = Complete.ASCII

local function _insert(modeS, category, value)
   -- Non-symbol character accepts the completion
   -- #todo should be consistent with lex.orb definition
   if find(value, "[^a-zA-Z0-9_]") then
      _accept(modeS, category, value)
      -- Retry with the new raga
      -- #todo should we defer to modeS:act() here instead?
      modeS.modes[category](modeS, category, value)
   else
      _default_insert(modeS, category, value)
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
   -- #todo dispatch this properly, technically the new raga
   -- may not have a handler for it
   modeS.modes.NAV.RIGHT(modeS, category, value)
end

NAV.RETURN = _accept
function NAV.LEFT(modeS, category, value)
   _accept(modeS, category, value)
   -- #todo dispatch this properly
   modeS.modes.NAV.LEFT(modeS, category, value)
end



return Complete
