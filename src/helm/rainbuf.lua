



























































local lineGen = (require "helm/repr").lineGen






local Rainbuf = meta {}














local clear, insert, lines = assert(table.clear),
                             assert(table.insert),
                             assert(string.lines)

function Rainbuf.lineGen(rainbuf, rows, cols)
   local offset = rainbuf.offset or 0
   cols = cols or 80
   if rainbuf.live then
      -- this buffer needs a fresh render each time
      rainbuf.reprs = nil
      clear(rainbuf.lines)
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
   if not rainbuf.lines then
      rainbuf.lines = {}
   end
   rainbuf.more = true
   local function _nextLine()
      cursor = cursor + 1
      -- Off the end
      if cursor > max_row then
         return nil
      end
      -- Fill the lines array until there's a line available at the cursor,
      -- or we know there will not be one. Look one step ahead to correctly
      -- set .more
      while rainbuf.more and cursor + 1 > #rainbuf.lines do
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
      -- If this is the last line requested, but more are available,
      -- prepend a continuation marker, otherwise left padding
      local prefix = "   "
      if cursor == max_row and rainbuf.more then
         prefix = a.red "..."
      end
      return rainbuf.lines[cursor] and prefix .. rainbuf.lines[cursor]
   end
   return _nextLine
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
   end
   rainbuf.offset = 0
   rainbuf.lines = {}
   return rainbuf
end

Rainbuf.idEst = new

return new
