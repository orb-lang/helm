






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
   else
      modeS:shiftMode(modeS.raga_default)
      modeS:clearResults()
   end
end



local function _makeControl(num)
    return function(modeS, category, value)
       local searchResult = modeS.hist:search(tostring(modeS.txtbuf))
       if #searchResult > 0 then
          local result
          modeS.txtbuf, result = modeS.hist:index(searchResult.cursors[num])
          if not result then
             result = {n=1}
          end
          modeS:printResults(result)
          modeS:shiftMode(modeS.raga_default)
       else
          modeS:shiftMode(modeS.raga_default)
          modeS:clearResults()
       end
    end
end

for i = 1, 9 do
   Search.ALT["M-" ..tostring(i)] = _makeControl(i)
end

Search.NAV.UP = nil
Search.NAV.DOWN = nil



return Search
