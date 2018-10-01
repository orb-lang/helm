



























































local Rainbuf = meta {}



























function Rainbuf.lineGen(rainbuf, rows, offset)
   offset = offset or 0
   -- #todo generate rainbuf.lines if empty
   rows = rows or #rainbuf.lines
   local cursor = 1 + offset
   rows = rows + offset
   return function()
      if cursor <= rows then
         local line = rainbuf.lines[cursor]
         if not line then
            return nil
         end
         cursor = cursor + 1
         return line
      else
         if cursor < #rainbuf.lines then
            rainbuf.more = true
         end
         return nil
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
   end
   rainbuf.lines = {}
   rainbuf.wids  = {}
   rainbuf.offset = 0
   return rainbuf
end

Rainbuf.idEst = new

return new
