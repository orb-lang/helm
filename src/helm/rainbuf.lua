



























































local lineGen = import("repr:repr", "lineGen")






local Rainbuf = meta {}










local clear = assert(table.clear)
function Rainbuf.clearCaches(rainbuf)
   rainbuf.reprs = nil
   rainbuf.r_num = nil
   clear(rainbuf.lines)
end







local lines = import("core/string", "lines")
function Rainbuf.initComposition(rainbuf, cols)
   cols = cols or 80
   if rainbuf.scrollable then
      cols = cols - 3
   end
   if rainbuf.live then
      -- this buffer needs a fresh render each time
      rainbuf:clearCaches()
   end
   if not rainbuf.reprs then
      rainbuf.reprs = {}
      rainbuf.r_num = 1
      rainbuf.more = true
      for i = 1, rainbuf.n do
         rainbuf.reprs[i] = rainbuf.frozen
            and lines(rainbuf[i])
            or lineGen(rainbuf[i], cols)
      end
   end
end









local insert = assert(table.insert)
function Rainbuf.composeOneLine(rainbuf)
   while true do
      local repr = rainbuf.reprs[rainbuf.r_num]
      if not repr then
         rainbuf.more = false
         return false
      end
      local line = repr()
      if line then
         insert(rainbuf.lines, line)
         return true
      else
         rainbuf.r_num = rainbuf.r_num + 1
      end
   end
end








function Rainbuf.composeUpTo(rainbuf, line_number)
   while rainbuf.more and #rainbuf.lines < line_number do
      rainbuf:composeOneLine()
   end
   return rainbuf.more
end







function Rainbuf.composeAll(rainbuf)
   while rainbuf.more do
      rainbuf:composeOneLine()
   end
   return rainbuf
end











function Rainbuf.lineGen(rainbuf, rows, cols)
   rainbuf:initComposition(cols)
   -- state for iterator
   local cursor = rainbuf.offset
   local max_row = rainbuf.offset + rows
   local function _nextLine()
      -- Off the end
      if cursor >= max_row then
         return nil
      end
      cursor = cursor + 1
      rainbuf:composeUpTo(cursor)
      local prefix = ""
      if rainbuf.scrollable then
         -- If this is the last line requested, but more are available,
         -- prepend a continuation marker, otherwise left padding
         prefix = "   "
         if cursor == max_row and rainbuf.more then
            prefix = a.red "..."
         end
      end
      return rainbuf.lines[cursor] and prefix .. rainbuf.lines[cursor]
   end
   return _nextLine
end





local function new(res)
   if type(res) == "table" and res.idEst == Rainbuf then
      return res
   end
   local rainbuf = meta(Rainbuf)
   assert(res.n, "must have n")
   if res then
      for i = 1, res.n do
         rainbuf[i] = res[i]
      end
      rainbuf.n = res.n
      rainbuf.frozen = res.frozen
      rainbuf.live = res.live
      rainbuf.scrollable = res.scrollable
   end
   rainbuf.offset = 0
   rainbuf.lines = {}
   return rainbuf
end

Rainbuf.idEst = new

return new
