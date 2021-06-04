




local clone = import("core/table", "clone")
local EditBase = require "helm/raga/edit"

local Complete = clone(EditBase, 2)

Complete.name = "complete"
Complete.prompt_char = "💬"






local function _quit(modeS)
   -- #todo restore last-used raga instead of always returning to default
   modeS.shift_to = modeS.raga_default
end

local function _accept(modeS)
   if modeS.suggest.last_collection then
      modeS.suggest:accept(modeS.txtbuf)
   else
      modeS.action_complete = false
   end
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

local function _scrollAfter(modeS, func_name)
   local suggestions = modeS.suggest.last_collection
   if suggestions then
      -- #todo route selection commands through the SuggestAgent or Window so
      -- it can set .touched itself?
      suggestions[func_name](suggestions)
      modeS.suggest.touched = true
      -- #todo should have a Selectbuf that does this automatically
      modeS.zones.suggest.contents:ensureVisible(suggestions.selected_index)
   end
end

function NAV.TAB(modeS, category, value)
   _scrollAfter(modeS, "selectNextWrap")
end
NAV.DOWN = NAV.TAB
NAV.SHIFT_DOWN = NAV.TAB

function NAV.SHIFT_TAB(modeS, category, value)
   _scrollAfter(modeS, "selectPreviousWrap")
end
NAV.UP = NAV.SHIFT_TAB
NAV.SHIFT_UP = NAV.SHIFT_TAB

NAV.ESC = _quit
NAV.RETURN = _accept

function NAV.LEFT(modeS, category, value)
   _accept(modeS, category, value)
   modeS.action_complete = false
end










function Complete.onTxtbufChanged(modeS)
   modeS.suggest:update(modeS.txtbuf, modeS.zones.suggest)
   if modeS.suggest.last_collection then
      modeS.suggest.last_collection.selected_index = 1
   end
   if not modeS.suggest.last_collection then
      _quit(modeS)
   end
   EditBase.onTxtbufChanged(modeS)
end










function Complete.onCursorChanged(modeS)
   _quit(modeS)
   EditBase.onCursorChanged(modeS)
end









local Point = require "anterm:point"
function Complete.getCursorPosition(modeS)
   local point = EditBase.getCursorPosition(modeS)
   local suggestion = modeS.suggest.last_collection:selectedItem()
   if suggestion then
      for _, tok in ipairs(modeS.txtbuf:tokens()) do
         if tok.cursor_offset then
            point = point + Point(0, #suggestion - tok.cursor_offset)
            break
         end
      end
   end
   return point
end








function Complete.onShift(modeS)
   _scrollAfter(modeS, "selectFirst")
end








function Complete.onUnshift(modeS)
   _scrollAfter(modeS, "selectNone")
end



return Complete

