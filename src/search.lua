






local clone = assert(table.clone, "requires table.clone")



local Nerf = require "nerf"

local Search = clone(Nerf, 3)




function Search.NAV.RETURN(modeS, category, value)
   local searchResult = modeS.hist:search(tostring(modeS.txtbuf))
   if #searchResult > 0 then
      local result
      modeS.txtbuf, result = modeS.hist:index(searchResult.cursors[1])
      if not result then
         result = {n=1}
      end
      modeS:printResults(result)
      modeS:shiftMode(modeS.raga_default)
   end
end



return Search
