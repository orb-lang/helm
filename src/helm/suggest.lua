







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









local function _cursorContext(modeS)
   local cur_row, cur_col = modeS.txtbuf:getCursor()
   cur_col = cur_col - 1
   local tokens = modeS.lex(tostring(modeS.txtbuf))
   local row, disp = 1, 0
   for _, token in ipairs(tokens) do
      if row < cur_row then
         if token:toStringBW() == "\n" then
            row = row + 1
         end
      else
         disp = disp + token.total_disp
         -- #todo handle typing in the middle of a token
         if disp >= cur_col then
            return token
         end
      end
   end
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
   -- Ignore mouse events to reduce flicker
   if category == "MOUSE" then
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
   suggestions.frag = context:toStringBW()
   suggestions.lit_frag = suggestions.frag
   local match_string = "^" .. litpat(suggestions.frag)
   for sym in pairs(names.all_symbols) do
      if match(sym, match_string) then
         insert(suggestions, sym)
      end
   end
   sort(suggestions, _suggest_sort)
   suggestions = Rainbuf { [1] = suggestions, n = 1,
                               live = true, made_in = "suggest.update" }
   modeS.zones.suggest:replace(suggestions)
end






function Suggest.cancel(suggest, modeS)
   modeS.zones.suggest:replace("")
end








new = function()
   local suggest = meta(Suggest)
   return suggest
end




Suggest.idEst = new
return new
