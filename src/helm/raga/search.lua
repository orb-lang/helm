





local clone = import("core/table", "clone")
local Nerf = require "helm/raga/nerf"
local Rainbuf = require "helm/rainbuf"

local Search = clone(Nerf, 3)

Search.prompt_char = "⁉️"




function Search.NAV.RETURN(modeS, category, value)
   local search_result = modeS.hist.last_collection[1]
   local result
   if #search_result > 0 then
      local selected_index = search_result.selected_index
      modeS.txtbuf, result = modeS.hist:index(search_result.cursors[selected_index])
   end
   modeS:shiftMode(modeS.raga_default)
   modeS:setResults(result)
end



function Search.NAV.SHIFT_DOWN(modeS, category, value)
   local search_buf = modeS.hist.last_collection
   if not search_buf then return end
   local search_result = search_buf[1]
   if search_result:selectNext() then
      if search_result.selected_index >= search_buf.offset + modeS.zones.results:height() then
        search_buf:scrollDown()
      end
      modeS.zones.results.touched = true
   end
end



function Search.NAV.SHIFT_UP(modeS, category, value)
   local search_buf = modeS.hist.last_collection
   if not search_buf then return end
   local search_result = search_buf[1]
   if search_result:selectPrevious() then
      if search_result.selected_index < search_buf.offset then
         search_buf:scrollUp()
      end
      modeS.zones.results.touched = true
   end
end











Search.NAV.UP = Search.NAV.SHIFT_UP
Search.NAV.DOWN = Search.NAV.SHIFT_DOWN




local function _makeControl(num)
   return function(modeS, category, value)
       local searchResult = modeS.hist:search(tostring(modeS.txtbuf))[1]
       if #searchResult > 0 then
         local result
         modeS.txtbuf, result = modeS.hist:index(searchResult.cursors[num])
         if not result then
             result = {n=1}
         end
         modeS.zones.results:replace(Rainbuf(result))
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





function Search.MOUSE(modeS, category, value)
   if value.scrolling then
      if value.button == "MB0" then
         modeS.modes.NAV.SHIFT_DOWN(modeS, category, value)
      elseif value.button == "MB1" then
         modeS.modes.NAV.SHIFT_UP(modeS, category, value)
      end
   end
end



return Search
