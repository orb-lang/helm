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
   local searchResult = modeS.hist:search(tostring(modeS.txtbuf)
   if #searchResult > 0 then
      local result
      modeS.txtbuf, result = modeS.hist:index(searchResult.cursor[1])
      modeS.printResults(result)
   end
end
```
