























local core = require "qor:core"
local math = core.math

local Rainbuf = require "helm:buf/rainbuf"
local Resbuf  = require "helm:buf/resbuf"
local Txtbuf  = require "helm:buf/txtbuf"

local Reviewbuf = core.cluster.meta(getmetatable(Rainbuf))






-- The (maximum) number of rows we will use for the "line" (command)
-- (in case it is many lines long)
Reviewbuf.ROWS_PER_LINE = 4
-- The (maximum) number of rows we will use for the result of the selected line
Reviewbuf.ROWS_PER_RESULT = 7













function Reviewbuf.contentCols(buf)
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

local function _txtbuf(buf, index)
   if not buf.txtbufs[index] then
      -- Stuff any uninitialized slots with `false`
      -- to maintain correct insert/remove behavior
      for i = #buf.txtbufs + 1, index - 1 do
         buf.txtbufs[i] = false
      end
      buf.txtbufs[index] = Txtbuf(buf.source.editWindow(index))
      _set_txtbuf_extent(buf, index)
   end
   return buf.txtbufs[index]
end










local insert, remove = assert(table.insert), assert(table.remove)
function Reviewbuf.roundInserted(buf, index)
   -- Similar to the agent, we lazy-init so just need to make space,
   -- but do need a non-nil value to hold the slot
   insert(buf.txtbufs, index, false)
end

function Reviewbuf.roundRemoved(buf, index)
   remove(buf.txtbufs, index)
end









function Reviewbuf.setSubExtents(buf)
   if not (buf.rows and buf.cols) then return end
   _set_resbuf_extent(buf)
   for index in ipairs(buf.txtbufs) do
      _set_txtbuf_extent(buf, index)
   end
end

function Reviewbuf.setExtent(buf, rows, cols)
   Rainbuf.setExtent(buf, rows, cols)
   buf:setSubExtents()
end










function Reviewbuf.checkTouched(buf)
   if buf.resbuf and buf.resbuf:checkTouched() then
      buf:beTouched()
   end
   for _, txtbuf in pairs(buf.txtbufs) do
      -- Could have `false` stuffing
      if txtbuf and txtbuf:checkTouched() then
         buf:beTouched()
      end
   end
   return Rainbuf.checkTouched(buf)
end










local clamp = assert(math.clamp)
function Reviewbuf.rowsForSelectedResult(buf)
   _resbuf(buf):composeUpTo(buf.ROWS_PER_RESULT)
   return clamp(#_resbuf(buf).lines, 0, buf.ROWS_PER_RESULT)
end








function Reviewbuf.positionOf(buf, index)
   local position = 1
   for i = 1, index - 1 do
      local num_lines = clamp(buf:value()[i]:lineCount(), 1, buf.ROWS_PER_LINE)
      position = position + num_lines + 1
      if i == buf.source.selected_index then
         position = position + buf:rowsForSelectedResult() + 1
      end
   end
   return position
end

function Reviewbuf.positionOfSelected(buf)
   return buf:positionOf(buf.source.selected_index)
end








function Reviewbuf.ensureSelectedVisible(buf)
   local start_index = buf:positionOfSelected()
   local end_index = start_index + buf:rowsForSelectedResult() + 3
   buf:ensureVisible(start_index, end_index)
end









function Reviewbuf.processQueuedMessages(buf)
   local had_any = false
   if buf.resbuf and buf.resbuf:processQueuedMessages() then
      had_any = true
   end
   for _, txtbuf in pairs(buf.txtbufs) do
      -- Could have `false` stuffing
      if txtbuf and txtbuf:processQueuedMessages() then
         had_any = true
      end
   end
   -- Anything from sub-buffers means we need to clear our line cache as well
   if had_any then
      buf:clearCaches()
   end
   if Rainbuf.processQueuedMessages(buf) then
      had_any = true
   end
   return had_any
end













function Reviewbuf.clearCaches(buf)
   Rainbuf.clearCaches(buf)
   buf._composeOneLine = nil
end






local wrap = assert(coroutine.wrap)
function Reviewbuf.initComposition(buf)
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
   watch  = "👁",
   report = "❗️",
   fail   = "❌",
   warn   = "✋",
   -- iTerm displays the trash-can emoji double-wide,
   -- but only advances the cursor one cell
   trash  = "🗑 ",
   keep   = "✅",
   insert = "👉"
}

local box_light = assert(require "anterm:box" . light)
local yield = assert(coroutine.yield)
local c = assert(require "singletons:color" . color)

function Reviewbuf._composeAll(buf)
   local function box_line(line_type)
      return box_light[line_type .. "Line"](box_light, buf:contentCols())
   end
   for i, round in ipairs(buf:value()) do
      yield(box_line(i == 1 and "top" or "spanning"))
      -- Render the line (which could actually be multiple physical lines)
      local line_prefix = status_icons[round.status] .. ' '
      for line in _txtbuf(buf, i):lineGen() do
         -- Selected round gets a highlight
         if i == buf.source.selected_index then
            line = c.highlight(line)
         end
         yield(box_line"content" .. line_prefix .. line)
         line_prefix = '   '
      end
      -- Selected round also displays results
      if i == buf.source.selected_index then
         yield(box_line"spanning")
         for line in _resbuf(buf):lineGen() do
            yield(box_line"content" .. line)
         end
      end
   end
   if #buf:value() == 0 then
      yield(box_line"top")
      yield(box_line"content" .. "No rounds to display")
   end
   yield(box_line"bottom")
   buf._composeOneLine = nil
end










function Reviewbuf._init(buf)
   Rainbuf._init(buf)
   buf.txtbufs = {}
end




return core.cluster.constructor(Reviewbuf)

