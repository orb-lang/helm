



























































local repr = require "helm/repr"
local ts, lineGen = repr.ts, repr.lineGen






local Rainbuf = meta {}














function Rainbuf.lineGen(rainbuf, rows, cols)
   offset = rainbuf.offset or 0
   cols = cols or 80
   if rainbuf.live then
      -- this buffer needs a fresh render each time
      rainbuf.reprs, rainbuf.lines = nil, nil
   end
   if not rainbuf.reprs then
      local reprs = {}
      for i = 1, rainbuf.n do
         if rainbuf.frozen then
            reprs[i] = string.lines(rainbuf[i])
         else
            reprs[i] = lineGen(rainbuf[i], cols)
            if type(reprs[i]) == "string" then
               reprs[i] = string.lines(reprs[i])
            end
         end
      end
      rainbuf.reprs = reprs
   end
   -- state for iterator
   local reprs = rainbuf.reprs
   local r_num = 1
   local cursor = 1 + offset
   rows = rows + offset
   if not rainbuf.lines then
      rainbuf.lines = {}
   end
   rainbuf.more = true
   local flip = true
   local function _nextLine()
      -- if we have lines, yield them
      if cursor < rows then
         if rainbuf.lines and cursor <= #rainbuf.lines then
            -- deal with line case
            cursor = cursor + 1
            return rainbuf.lines[cursor - 1]
         elseif rainbuf.more then
            local repr = reprs[r_num]
            if repr == nil then
               rainbuf.more = false
               return nil
            end
            local line = repr()  -- #todo fix dead coroutine problem here
            if line ~= nil then
               rainbuf.lines[#rainbuf.lines + 1] = line
               if offset <= #rainbuf.lines then
                  cursor = cursor + 1
                  return line
               else
                  return _nextLine()
               end
            else
               r_num = r_num + 1
               return _nextLine()
            end
         end
      else
         return nil
      end
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
   -- these aren't in play yet
   rainbuf.wids  = {}
   rainbuf.offset = 0
   return rainbuf
end

Rainbuf.idEst = new

return new
