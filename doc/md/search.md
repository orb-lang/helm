# Search


A light wrapper over ``nerf``.


```lua
local clone = assert(table.clone, "requires table.clone")
```
```lua
local Nerf = require "nerf"

local Search = clone(Nerf, 3)
```
```lua
function Search.NAV.RETURN(modeS, category, value)
   local searchResult = modeS.hist:search(tostring(modeS.txtbuf))
   if #searchResult > 0 then
      local result
      local hl = searchResult.hl
      modeS.txtbuf, result = modeS.hist:index(searchResult.cursors[hl])
      if not result then
         result = {n=1}
      end
      modeS.zones.results:replace(result)
      modeS:shiftMode(modeS.raga_default)
   else
      modeS:shiftMode(modeS.raga_default)
      modeS.zones.results:replace ""
   end
end
```
```lua
local function _makeControl(num)
    return function(modeS, category, value)
       local searchResult = modeS.hist:search(tostring(modeS.txtbuf))
       if #searchResult > 0 then
          local result
          modeS.txtbuf, result = modeS.hist:index(searchResult.cursors[num])
          if not result then
             result = {n=1}
          end
          modeS.zones.results:replace(result)
          modeS:shiftMode(modeS.raga_default)
       else
          modeS:shiftMode(modeS.raga_default)
          modeS.zones.results:replace ""
       end
    end
end

for i = 1, 9 do
   Search.ALT["M-" ..tostring(i)] = _makeControl(i)
end
```
### UP and DOWN

Disabled for now, intended to choose among options

```lua
Search.NAV.UP = nil
Search.NAV.DOWN = nil
```
```lua
return Search
```
