



















local Rainbuf = require "helm:buf/rainbuf"
local Txtbuf = Rainbuf:inherit()






function Txtbuf.clearCaches(txtbuf)
   txtbuf:super"clearCaches"()
   txtbuf.render_row = nil
end






function Txtbuf.initComposition(txtbuf)
   txtbuf.render_row = txtbuf.render_row or 1
end






local c = assert(require "singletons:color" . color)
local concat = assert(table.concat)
function Txtbuf._composeOneLine(txtbuf)
   if txtbuf.render_row > #txtbuf:value() then return nil end
   local tokens = txtbuf.source.tokens(txtbuf.render_row)
   local suggestion = txtbuf.suggestions
      and txtbuf.suggestions:selectedItem()
   for i, tok in ipairs(tokens) do
      -- If suggestions are active and one is highlighted,
      -- display it in grey instead of what the user has typed so far
      -- Note this only applies once Tab has been pressed, as until then
      -- :selectedItem() will be nil
      if suggestion and tok.cursor_offset then
         tokens[i] = txtbuf.suggestions.highlight(suggestion, txtbuf:contentCols(), c)
      else
         tokens[i] = tok:toString(c)
      end
   end
   txtbuf.render_row = txtbuf.render_row + 1
   return concat(tokens)
end











function Txtbuf.checkTouched(txtbuf)
   if txtbuf.suggestions and txtbuf.suggestions.touched then
      txtbuf:beTouched()
   end
   return txtbuf:super"checkTouched"()
end




local Txtbuf_class = setmetatable({}, Txtbuf)
Txtbuf.idEst = Txtbuf_class

return Txtbuf_class

