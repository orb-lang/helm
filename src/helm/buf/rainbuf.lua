



























































local lineGen = import("repr:repr", "lineGen")






local Rainbuf = meta {}












local lines = import("core/string", "lines")
function Rainbuf.setExtent(rainbuf, rows, cols)
   rows = rows or 20
   cols = cols or 80
   -- If width is changing, we need a re-render
   if cols ~= rainbuf.cols then
      rainbuf:clearCaches()
   end
   -- If the number of rows is increasing, may need to adjust our offset
   -- to avoid blank lines at the bottom. Note that if cols has also changed
   -- we don't know what's going on--but rainbuf.more will have also been reset
   -- so we won't try anything
   if rainbuf.rows and rows > rainbuf.rows and not rainbuf.more then
      -- #todo actually do the thing
   end
   rainbuf.rows = rows
   rainbuf.cols = cols
end









function Rainbuf.contentCols(rainbuf)
   return rainbuf.scrollable and rainbuf.cols - 3 or rainbuf.cols
end



















local clamp = import("core/math", "clamp")
function Rainbuf.scrollTo(rainbuf, offset, allow_overscroll)
   if offset < 0 then
      offset = 0
   end
   if offset ~= 0 then
      -- Try to render the content that will be visible after the scroll
      rainbuf:composeUpTo(offset + rainbuf.rows)
      local required_lines_visible = allow_overscroll and 1 or rainbuf.rows
      local max_offset = clamp(#rainbuf.lines - required_lines_visible, 0)
      offset = clamp(offset, 0, max_offset)
   end
   if offset ~= rainbuf.offset then
      rainbuf.offset = offset
      rainbuf:beTouched()
      return true
   else
      return false
   end
end








function Rainbuf.scrollBy(rainbuf, delta, allow_overscroll)
   return rainbuf:scrollTo(rainbuf.offset + delta, allow_overscroll)
end








function Rainbuf.scrollUp(rainbuf, count)
   count = count or 1
   return rainbuf:scrollBy(-count)
end
function Rainbuf.scrollDown(rainbuf, count)
   count = count or 1
   return rainbuf:scrollBy(count)
end

function Rainbuf.pageUp(rainbuf)
   return rainbuf:scrollBy(-rainbuf.rows)
end
function Rainbuf.pageDown(rainbuf)
   return rainbuf:scrollBy(rainbuf.rows)
end

local floor = assert(math.floor)
function Rainbuf.halfPageUp(rainbuf)
   return rainbuf:scrollBy(-floor(rainbuf.rows / 2))
end
function Rainbuf.halfPageDown(rainbuf)
   return rainbuf:scrollBy(floor(rainbuf.rows / 2))
end











function Rainbuf.scrollToTop(rainbuf)
   return rainbuf:scrollTo(0)
end

function Rainbuf.scrollToBottom(rainbuf, allow_overscroll)
   rainbuf:composeAll()
   -- Choose a definitely out-of-range value,
   -- which scrollTo will clamp appropriately
   return rainbuf:scrollTo(#rainbuf.lines, allow_overscroll)
end











function Rainbuf.ensureVisible(rainbuf, start_index, end_index)
   end_index = end_index or start_index
   local min_offset = clamp(end_index - rainbuf.rows, 0)
   local max_offset = clamp(start_index - 1, 0)
   rainbuf:scrollTo(clamp(rainbuf.offset, min_offset, max_offset))
end






















local insert = assert(table.insert)
function Rainbuf.composeOneLine(rainbuf)
   local line = rainbuf:_composeOneLine()
   if line then
      insert(rainbuf.lines, line)
      return true
   else
      rainbuf.more = false
      return false
   end
end
















function Rainbuf.composeUpTo(rainbuf, line_number)
   rainbuf:initComposition()
   while rainbuf.more and #rainbuf.lines <= line_number do
      rainbuf:composeOneLine()
   end
   return rainbuf
end








function Rainbuf.composeAll(rainbuf)
   rainbuf:initComposition()
   while rainbuf.more do
      rainbuf:composeOneLine()
   end
   return rainbuf
end













function Rainbuf.lineGen(rainbuf)
   rainbuf:initComposition()
   -- state for iterator
   local cursor = rainbuf.offset
   local max_row = rainbuf.offset + rainbuf.rows
   local function _nextLine()
      -- Off the end
      if cursor >= max_row then
         return nil
      end
      cursor = cursor + 1
      rainbuf:composeUpTo(cursor)
      local prefix = ""
      if rainbuf.scrollable then
         -- Use a three-column gutter (which we reserved space for in
         -- :contentCols()) to display scrolling indicators.
         -- Up arrows at the top if scrolled down, down arrows at the bottom
         -- if more is available. Intervening lines get matching left padding
         if cursor == rainbuf.offset + 1 and rainbuf.offset > 0 then
            prefix = a.red "↑↑↑"
         elseif cursor == max_row and rainbuf.more then
            prefix = a.red "↓↓↓"
         else
            prefix = "   "
         end
      end
      return rainbuf.lines[cursor] and prefix .. rainbuf.lines[cursor]
   end
   return _nextLine
end












function Rainbuf.value(rainbuf)
   local value = rainbuf.source.buffer_value
   if value == nil then
      return rainbuf.null_value
   else
      return value
   end
end









local clear = assert(table.clear)
function Rainbuf.clearCaches(rainbuf)
   clear(rainbuf.lines)
   rainbuf.more = true
end









function Rainbuf.beTouched(rainbuf)
   rainbuf.touched = true
   rainbuf:clearCaches()
end

















function Rainbuf.checkTouched(rainbuf)
   if rainbuf.source:checkTouched() then
      rainbuf:beTouched()
   end
   local touched = rainbuf.touched
   rainbuf.touched = false
   return touched
end











function Rainbuf._init(rainbuf)
   rainbuf.offset = 0
   rainbuf.lines = {}
   rainbuf.touched = true
end











function Rainbuf.__call(buf_class, source, cfg)
   local buf_M = getmetatable(buf_class)
   local rainbuf = setmetatable({}, buf_M)
   -- Kinda-hacky detection of something that isn't a proper source.
   -- Wrap it in a dummy table so we can function properly.
   if not source.checkTouched then
      source = {
         buffer_value = source,
         checkTouched = function() return false end
      }
   end
   rainbuf.source = source
   rainbuf:_init()
   for k, v in pairs(cfg or {}) do
      rainbuf[k] = v
   end
   return rainbuf
end








Rainbuf.super = assert(require "core:cluster" . super)









Rainbuf.is_rainbuf = true




local constructor = assert(require "core:cluster" . constructor)
return constructor(Rainbuf)

