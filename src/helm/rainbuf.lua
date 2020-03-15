



























































local lineGen = import("helm/repr", "lineGen")






local Rainbuf = meta {}










function Rainbuf.clearCaches(rainbuf)
   rainbuf.reprs = nil
   clear(rainbuf.lines)
end











local clear, insert = assert(table.clear),
                      assert(table.insert)
local lines = import("core/string", "lines")

function Rainbuf.lineGen(rainbuf, rows, cols)
   local offset = rainbuf.offset or 0
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
      for i = 1, rainbuf.n do
         rainbuf.reprs[i] = rainbuf.frozen
            and lines(rainbuf[i])
            or lineGen(rainbuf[i], cols)
      end
   end
   -- state for iterator
   local r_num = 1
   local cursor = offset
   local max_row = offset + rows
   rainbuf.more = true
   local function _nextLine()
      -- Off the end
      if cursor >= max_row then
         return nil
      end
      cursor = cursor + 1
      -- Fill the lines array until there's a line available at the cursor,
      -- or we know there will not be one. Look one step ahead to correctly
      -- set .more
      while rainbuf.more and cursor >= #rainbuf.lines do
         local repr = rainbuf.reprs[r_num]
         -- Out of content
         if repr == nil then
            rainbuf.more = false
         else
            local line = repr()
            if line then
               insert(rainbuf.lines, line)
            else
               r_num = r_num + 1
            end
         end
      end
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








function Rainbuf.scrollUp(rainbuf)
   if rainbuf.offset > 0 then
      rainbuf.offset = rainbuf.offset - 1
      return true
   else
      return false
   end
end

function Rainbuf.scrollDown(rainbuf)
   if rainbuf.more then
      rainbuf.offset = rainbuf.offset + 1
      return true
   else
      return false
   end
end





local function new(res)
   if type(res) == "table" and res.idEst == Rainbuf then
      error "made a Rainbuf from a Rainbuf"
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
