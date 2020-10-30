




local clone = import("core/table", "clone")
local EditBase = require "helm/raga/edit"

local Complete = clone(EditBase, 2)

Complete.name = "complete"
Complete.prompt_char = "💬"






local function _quit(modeS)
   modeS.suggest:cancel(modeS)
   -- #todo restore last-used raga instead of always returning to default
   modeS.shift_to = modeS.raga_default
end

local function _accept(modeS)
   if modeS.suggest.active_suggestions then
      modeS.suggest:accept(modeS)
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
   local suggestions = modeS.suggest.active_suggestions
   local zone = modeS.zones.suggest
   suggestions[func_name](suggestions)
   if suggestions.selected_index - zone.contents.offset > zone:height() then
      zone:scrollTo(suggestions.selected_index - zone:height())
   elseif suggestions.selected_index <= zone.contents.offset then
      zone:scrollTo(suggestions.selected_index - 1)
   end
   zone:beTouched()
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
function NAV.RIGHT(modeS, category, value)
   _quit(modeS, category, value)
   modeS.action_complete = false
end

NAV.RETURN = _accept
function NAV.LEFT(modeS, category, value)
   _accept(modeS, category, value)
   modeS.action_complete = false
end





function Complete.onCursorChanged(modeS)
   modeS.suggest:update(modeS)
   EditBase.onCursorChanged(modeS)
end









local Point = require "anterm:point"
function Complete.getCursorPosition(modeS)
   local point = EditBase.getCursorPosition(modeS)
   local suggestion = modeS.suggest:selectedSuggestion()
   if suggestion then
      for _, tok in ipairs(modeS.lex(modeS.txtbuf)) do
         if tok.cursor_offset then
            point = point + Point(0, #suggestion - tok.cursor_offset)
            break
         end
      end
   end
   return point
end




return Complete

