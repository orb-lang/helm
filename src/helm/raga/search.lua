





local clone = import("core/table", "clone")
local EditBase = require "helm/raga/edit"
local Txtbuf = require "helm:buf/txtbuf"
local Resbuf = require "helm:buf/resbuf"

local Search = clone(EditBase, 2)

Search.name = "search"
Search.prompt_char = "⁉️"








function Search.onTxtbufChanged(modeS)
   local searchResult = modeS.hist:search(tostring(modeS.txtbuf))
   modeS:setResults({ searchResult, n = 1 })
end






local NAV = Search.NAV

function NAV.SHIFT_DOWN(modeS, category, value)
   local search_result = modeS.hist.last_collection
   if not search_result then return end
   if search_result:selectNext() then
      local search_buf = modeS.zones.results.contents
      -- #todo route this through a Window that can handle the
      -- change-detection automatically
      search_buf:beTouched()
      search_buf:ensureVisible(search_result.selected_index)
      modeS.txtbuf:beTouched()
   end
end



function NAV.SHIFT_UP(modeS, category, value)
   local search_result = modeS.hist.last_collection
   if search_result:selectPrevious() then
      local search_buf = modeS.zones.results.contents
      search_buf:beTouched()
      search_buf:ensureVisible(search_result.selected_index)
      modeS.txtbuf:beTouched()
   end
end



function NAV.ESC(modeS, category, value)
   local search_result = modeS.hist.last_collection
   -- No results or nothing is selected, exit search mode
   if not search_result or search_result.selected_index == 0 then
      modeS.shift_to = modeS.raga_default
      modeS:setResults("")
   -- If something *is* selected, deselect it first
   else
      search_result:selectNone()
      local search_buf = modeS.zones.results.contents
      search_buf:ensureVisible(1)
      search_buf:beTouched()
      modeS.txtbuf:beTouched()
   end
end











NAV.DOWN      = NAV.SHIFT_DOWN
NAV.TAB       = NAV.SHIFT_DOWN
NAV.UP        = NAV.SHIFT_UP
NAV.SHIFT_TAB = NAV.SHIFT_UP

local function _modeShiftOnDeleteWhenEmpty(modeS, category, value)
   if tostring(modeS.txtbuf) == "" then
      modeS.shift_to = modeS.raga_default
      modeS:setResults("")
   else
      EditBase(modeS, category, value)
   end
end

NAV.BACKSPACE = _modeShiftOnDeleteWhenEmpty
NAV.DELETE    = _modeShiftOnDeleteWhenEmpty







local function _acceptAtIndex(modeS, selected_index)
   local search_result = modeS.hist.last_collection
   local line, result
   if #search_result > 0 then
      selected_index = selected_index or search_result.selected_index
      if selected_index == 0 then selected_index = 1 end
      line, result = modeS.hist:index(search_result.cursors[selected_index])
   end
   modeS.shift_to = modeS.raga_default
   modeS:setTxtbuf(Txtbuf(line), result)
   modeS:setResults(result)
end

function NAV.RETURN(modeS, category, value)
   _acceptAtIndex(modeS)
end

local function _makeControl(num)
   return function(modeS, category, value)
      _acceptAtIndex(modeS, num)
   end
end

for i = 1, 9 do
   Search.ALT["M-" ..tostring(i)] = _makeControl(i)
end






function Search.MOUSE(modeS, category, value)
   if value.scrolling then
      if value.button == "MB0" then
         modeS.raga.NAV.SHIFT_DOWN(modeS, category, value)
      elseif value.button == "MB1" then
         modeS.raga.NAV.SHIFT_UP(modeS, category, value)
      end
   end
end



return Search

