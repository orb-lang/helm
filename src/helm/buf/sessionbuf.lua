












local Rainbuf = require "helm:buf/rainbuf"
local Resbuf  = require "helm:buf/resbuf"
local Txtbuf  = require "helm:buf/txtbuf"

local Sessionbuf = Rainbuf:inherit()






-- The (maximum) number of rows we will use for the "line" (command)
-- (in case it is many lines long)
Sessionbuf.ROWS_PER_LINE = 4
-- The (maximum) number of rows we will use for the result of the selected line
Sessionbuf.ROWS_PER_RESULT = 7













function Sessionbuf.contentCols(buf)
   return buf:super"contentCols"() - 2
end









function Sessionbuf.setSubExtents(buf)
   if not (buf.rows and buf.cols) then return end
   -- Account for additional padding
   buf.resbuf:setExtent(buf.ROWS_PER_RESULT, buf:contentCols() - 2)
   for _, txtbuf in ipairs(buf.txtbufs) do
      -- As above, but additionally three cells for the icon and space after it
      txtbuf:setExtent(buf.ROWS_PER_LINE, buf:contentCols() - 5)
   end
end

function Sessionbuf.setExtent(buf, rows, cols)
   buf:super"setExtent"(rows, cols)
   buf:setSubExtents()
end










function Sessionbuf.checkTouched(buf)
   if buf.resbuf:checkTouched() then
      buf:beTouched()
   end
   for _, txtbuf in ipairs(buf.txtbufs) do
      if txtbuf:checkTouched() then
         buf:beTouched()
      end
   end
   return buf:super"checkTouched"()
end










local clamp = assert(require "core:math" . clamp)
function Sessionbuf.rowsForSelectedResult(buf)
   buf.resbuf:composeUpTo(buf.ROWS_PER_RESULT)
   return clamp(#buf.resbuf.lines, 0, buf.ROWS_PER_RESULT)
end








local gsub = assert(string.gsub)
function Sessionbuf.positionOf(buf, index)
   local position = 1
   for i = 1, index - 1 do
      local num_lines = select(2, gsub(buf.value[i].line, '\n', '\n')) + 1
      num_lines = clamp(num_lines, 1, buf.ROWS_PER_LINE)
      position = position + num_lines + 1
      if i == buf.selected_index then
         position = position + buf:rowsForSelectedResult() + 1
      end
   end
   return position
end

function Sessionbuf.positionOfSelected(buf)
   return buf:positionOf(buf.selected_index)
end








function Sessionbuf.scrollResultsDown(buf)
   return buf.resbuf:scrollDown()
end

function Sessionbuf.scrollResultsUp(buf)
   return buf.resbuf:scrollUp()
end













function Sessionbuf.clearCaches(buf)
   buf:super"clearCaches"()
   buf._composeOneLine = nil
end






local wrap = assert(coroutine.wrap)
function Sessionbuf.initComposition(buf)
   buf._composeOneLine = buf._composeOneLine or
      wrap(function() buf:_composeAll() end)
end










local status_icons = {
   ignore = "🟡",
   accept = "✅",
   reject = "🚫",
   skip   = "🗑 "
}

local box_light = assert(require "anterm:box" . light)
local yield = assert(coroutine.yield)
local c = assert(require "singletons:color" . color)
function Sessionbuf._composeAll(buf)
   for i, premise in ipairs(buf.value) do
      yield(i == 1
         and box_light:topLine(buf:contentCols())
         or box_light:spanningLine(buf:contentCols()))
      -- Render the line (which could actually be multiple physical lines)
      local line_prefix = box_light:contentLine(buf:contentCols()) ..
         status_icons[premise.status] .. ' '
      for line in buf.txtbufs[i]:lineGen() do
         -- Selected premise gets a highlight
         if i == buf.selected_index then
            line = c.highlight(line)
         end
         yield(line_prefix .. line)
         line_prefix = box_light:contentLine(buf:contentCols()) .. '   '
      end
      -- Selected premise also displays results
      if i == buf.selected_index then
         yield(box_light:spanningLine(buf:contentCols()))
         for line in buf.resbuf:lineGen() do
            yield(box_light:contentLine(buf:contentCols()) .. line)
         end
      end
   end
   if #buf.value == 0 then
      yield(box_light:topLine(buf:contentCols()))
      yield(box_light:contentLine(buf:contentCols()) .. "No premises to display")
   end
   yield(box_light:bottomLine(buf:contentCols()))
   buf._composeOneLine = nil
end








function Sessionbuf._init(buf)
   buf:super"_init"()
   buf.resbuf = Resbuf({ n = 0 }, { scrollable = true })
   buf.txtbufs = {}
end






local lua_thor = assert(require "helm:lex" . lua_thor)
function Sessionbuf.replace(buf, session)
   buf:super"replace"(session)
   for i, premise in ipairs(session) do
      buf.txtbufs[i] = Txtbuf(premise.line, { lex = lua_thor })
   end
   for i = #session + 1, #buf.txtbufs do
      buf.txtbufs[i] = nil
   end
   if buf.source then
      local result
      local premise = buf.source.selectedPremise()
      if premise then
         -- #todo re-evaluate sessions on -s startup, and display an
         -- indication of whether there are changes (and eventually a diff)
         -- rather than just the newest available result
         result = premise.new_result or premise.old_result
      end
      buf.resbuf:replace(result)
      -- #todo copy this so we don't completely blow up if we don't have a
      -- .source--but maybe we *should* be dependent like that, in which case
      -- who cares and we should just go to the source directly
      buf.selected_index = buf.source.selected_index
   end
   buf:setSubExtents()
end



local Sessionbuf_class = setmetatable({}, Sessionbuf)
Sessionbuf.idEst = Sessionbuf_class

return Sessionbuf_class

