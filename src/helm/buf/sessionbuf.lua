












local meta = assert(require "core:cluster" . Meta)
local Rainbuf = require "helm:buf/rainbuf"
local Resbuf  = require "helm:buf/resbuf"
local Txtbuf  = require "helm:buf/txtbuf"

local Sessionbuf = meta(getmetatable(Rainbuf))






-- The (maximum) number of rows we will use for the "line" (command)
-- (in case it is many lines long)
Sessionbuf.ROWS_PER_LINE = 4
-- The (maximum) number of rows we will use for the result of the selected line
Sessionbuf.ROWS_PER_RESULT = 7













function Sessionbuf.contentCols(buf)
   return Rainbuf.contentCols(buf) - 2
end








local function _set_resbuf_extent(buf)
   if buf.resbuf then
      -- Account for additional padding
      buf.resbuf:setExtent(buf.ROWS_PER_RESULT, buf:contentCols() - 2)
   end
end

local function _set_txtbuf_extent(buf, index)
   if buf.txtbufs[index] then
      -- As above, but additionally three cells for the icon and space after it
      buf.txtbufs[index]:setExtent(buf.ROWS_PER_LINE, buf:contentCols() - 5)
   end
end

local function _resbuf(buf)
   if not buf.resbuf then
      buf.resbuf = Resbuf(buf.source.resultsWindow(), { scrollable = true })
      _set_resbuf_extent(buf)
   end
   return buf.resbuf
end

local lua_thor = assert(require "helm:lex" . lua_thor)
local function _txtbuf(buf, index)
   if not buf.txtbufs[index] then
      buf.txtbufs[index] = Txtbuf(buf.source.editWindow(index), { lex = lua_thor })
      _set_txtbuf_extent(buf, index)
   end
   return buf.txtbufs[index]
end









function Sessionbuf.setSubExtents(buf)
   if not (buf.rows and buf.cols) then return end
   _set_resbuf_extent(buf)
   -- There'll probably never be holes in the txtbufs array, but it doesn't
   -- really matter what order we do this in, so better safe than sorry.
   for index in pairs(buf.txtbufs) do
      _set_txtbuf_extent(buf, index)
   end
end

function Sessionbuf.setExtent(buf, rows, cols)
   Rainbuf.setExtent(buf, rows, cols)
   buf:setSubExtents()
end










function Sessionbuf.checkTouched(buf)
   if buf.resbuf and buf.resbuf:checkTouched() then
      buf:beTouched()
   end
   for _, txtbuf in pairs(buf.txtbufs) do
      if txtbuf:checkTouched() then
         buf:beTouched()
      end
   end
   return Rainbuf.checkTouched(buf)
end










local clamp = assert(require "core:math" . clamp)
function Sessionbuf.rowsForSelectedResult(buf)
   _resbuf(buf):composeUpTo(buf.ROWS_PER_RESULT)
   return clamp(#_resbuf(buf).lines, 0, buf.ROWS_PER_RESULT)
end








local gsub = assert(string.gsub)
function Sessionbuf.positionOf(buf, index)
   local position = 1
   for i = 1, index - 1 do
      local num_lines = select(2, gsub(buf:value()[i].line, '\n', '\n')) + 1
      num_lines = clamp(num_lines, 1, buf.ROWS_PER_LINE)
      position = position + num_lines + 1
      if i == buf.source.selected_index then
         position = position + buf:rowsForSelectedResult() + 1
      end
   end
   return position
end

function Sessionbuf.positionOfSelected(buf)
   return buf:positionOf(buf.source.selected_index)
end








function Sessionbuf.scrollResultsDown(buf)
   return _resbuf(buf):scrollDown()
end

function Sessionbuf.scrollResultsUp(buf)
   return _resbuf(buf):scrollUp()
end













function Sessionbuf.clearCaches(buf)
   Rainbuf.clearCaches(buf)
   buf._composeOneLine = nil
end






local wrap = assert(coroutine.wrap)
function Sessionbuf.initComposition(buf)
   buf._composeOneLine = buf._composeOneLine or wrap(
      function()
         local success, err = xpcall(function() buf:_composeAll() end,
                                     debug.traceback)
         if not success then
            error(err)
         end
      end)
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
   local function box_line(line_type)
      return box_light[line_type .. "Line"](box_light, buf:contentCols())
   end
   for i, premise in ipairs(buf:value()) do
      yield(box_line(i == 1 and "top" or "spanning"))
      -- Render the line (which could actually be multiple physical lines)
      local line_prefix = status_icons[premise.status] .. ' '
      for line in _txtbuf(buf, i):lineGen() do
         -- Selected premise gets a highlight
         if i == buf.source.selected_index then
            line = c.highlight(line)
         end
         yield(box_line"content" .. line_prefix .. line)
         line_prefix = '   '
      end
      -- Selected premise also displays results
      if i == buf.source.selected_index then
         yield(box_line"spanning")
         for line in _resbuf(buf):lineGen() do
            yield(box_line"content" .. line)
         end
      end
   end
   if #buf:value() == 0 then
      yield(box_line"top")
      yield(box_line"content" .. "No premises to display")
   end
   yield(box_line"bottom")
   buf._composeOneLine = nil
end










function Sessionbuf._init(buf)
   Rainbuf._init(buf)
   buf.txtbufs = {}
end




local constructor = assert(require "core:cluster" . constructor)
return constructor(Sessionbuf)

