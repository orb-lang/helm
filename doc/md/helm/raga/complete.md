# Complete

Handles choosing and accepting a suggestion from ``suggest``.


Implemented for now as a wrapper over Nerf--should really be derived
from a common base of edit functionality, or (even better) defer somehow
to whatever the previous raga was.

```lua
local clone = import("core/table", "clone")
local Nerf = require "helm/raga/nerf"

local Complete = clone(Nerf, 3)
```
## Inserts

```lua

local function _quit(modeS, category, value)
   modeS.suggest:cancel(modeS)
   -- #todo restore last-used raga instead of always returning to default
   modeS:shiftMode(modeS.raga_default)
end

Complete.PASTE = function(modeS, category, value)
   _quit(modeS, category, value)
   modeS.modes.PASTE(modeS, category, value)
end

```
```lua
local find = assert(string.find)

local _default_insert = Complete.ASCII

local function _insert(modeS, category, value)
   -- Non-symbol character accepts the completion
   if find(value, "[^a-zA-Z0-9_]") then
      modeS.suggest:accept()
   end
   _default_insert(modeS, category, value)
end

Complete.ASCII = _insert
Complete.UTF8 = _insert
```
## NAV

```lua
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

function NAV.RETURN(modeS, category, value)
   modeS.suggest:accept()
   _quit(modeS, category, value)
end
```
```lua
return Complete
```
