







local Lex = require "helm/lex"
local SelectionList = require "helm/selection_list"
local Rainbuf = require "helm/rainbuf"
local names = require "helm/repr/names"
local concat, insert, sort = assert(table.concat),
                             assert(table.insert),
                             assert(table.sort)
local match = assert(string.match)
local c = import("singletons/color", "color")





local Suggest = meta {}
local new










local function _shouldUpdate(modeS, category, value)
   if category == "ASCII" or category == "UTF8" then
      return true
   end
   -- Deletion and moving the cursor should update the completion list
   -- #todo there's got to be a better way to do this
   if category == "NAV" and
      value == "BACKSPACE" or value == "DELETE" or
      value == "LEFT" or value == "RIGHT" then
      return true
   end
   return false
end









local function _cursorContext(modeS)
   local lex_tokens = modeS.lex(modeS.txtbuf)
   for _, token in ipairs(lex_tokens) do
      if token.cursor_offset then
         return token
      end
   end
   return nil
end

local function _suggest_sort(a, b)
   if #a ~= #b then
      return #a < #b
   else
      return a < b
   end
end

local litpat = import("core/string", "litpat")

function Suggest.update(suggest, modeS, category, value)
   if not _shouldUpdate(modeS, category, value) then
      return
   end
   local context = _cursorContext(modeS)
   -- #todo once we're using =palette=, we'll be able to check the name
   -- of the color rather than needing the color table ourselves
   if context == nil or context.color ~= c.field then
      suggest:cancel(modeS)
      return
   end
   local suggestions = SelectionList()
   suggestions.best = true
   suggestions.frag = tostring(context):sub(1, context.cursor_offset)
   suggestions.lit_frag = suggestions.frag
   local match_string = "^" .. litpat(suggestions.frag)
   for sym in pairs(names.all_symbols) do
      if match(sym, match_string) then
         insert(suggestions, sym)
      end
   end
   if #suggestions > 0 then
      sort(suggestions, _suggest_sort)
      if modeS.raga == "complete" then
         suggestions.selected_index = 1
      end
      suggestions = Rainbuf { [1] = suggestions, n = 1,
                                  live = true, made_in = "suggest.update" }
      suggest.active_suggestions = suggestions
      modeS.zones.suggest:replace(suggestions)
   else
      suggest:cancel(modeS)
   end
end






function Suggest.cancel(suggest, modeS)
   suggest.active_suggestions = nil
   modeS.zones.suggest:replace("")
end






local Txtbuf = require "helm/txtbuf"

function Suggest.accept(suggest, modeS)
   local suggestion = suggest.active_suggestions[1]:selectedItem()
   local context = _cursorContext(modeS)
   modeS.txtbuf:paste(suggestion:sub(context.cursor_offset + 1))
end






new = function()
   local suggest = meta(Suggest)
   return suggest
end




Suggest.idEst = new
return new
