



























































local color = require "color"
local ts = color.ts






local Rainbuf = meta {}



























function Rainbuf.lineGen(rainbuf, rows)
   offset = rainbuf.offset or 0
   if not rainbuf.lines then
      local phrase = ""
      for i = 1, rainbuf.n do
         local piece
         if rainbuf.frozen then
            piece = rainbuf[i]
         else
            piece = ts(rainbuf[i])
         end
         phrase = phrase .. piece
         if i < rainbuf.n then
            phrase = phrase .. "   "
         end
      end
      rainbuf.lines = table.collect(string.lines, phrase)
   end
   rows = rows or #rainbuf.lines
   local cursor = 1 + offset
   rows = rows + offset

   return function()
      if cursor <= rows then
         local line = rainbuf.lines[cursor]
         if not line then
            rainbuf.more = false
            return nil
         end
         cursor = cursor + 1
         return line
      else
         if cursor <= #rainbuf.lines then
            rainbuf.more = true
            return nil
         else
            rainbuf.more = false
            return nil
         end
      end
   end
end






function Rainbuf.__tostring(rainbuf)
end






local function new(res)
   local rainbuf = meta(Rainbuf)
   if res then
      for i = 1, res.n do
         rainbuf[i] = res[i]
      end
      rainbuf.n = res.n
      rainbuf.frozen = res.frozen
   end
   rainbuf.wids  = {}
   rainbuf.offset = 0
   return rainbuf
end

Rainbuf.idEst = new

return new
