



























































local repr = require "repr"
local ts, lineGen = repr.ts, repr.lineGen






local Rainbuf = meta {}



























function Rainbuf.lineGen(rainbuf, rows, cols)
   offset = rainbuf.offset or 0
   cols = cols or 80
   local reprs = {}
   if not rainbuf.lines then
      for i = 1, rainbuf.n do
         if rainbuf.frozen then
            reprs[i] = string.lines(rainbuf[i])
         else
            reprs[i] = lineGen(rainbuf[i], nil, nil, cols)
            if type(reprs[i]) == "string" then
               reprs[i] = string.lines(reprs[i])
            end
         end
      end
   end
   -- state for iterator
   local r_num = 1
   local cursor = 1 + offset

   local function _nextLine()
      -- if we have lines, yield them
      if rainbuf.lines then
         -- deal with line case
      else
         local repr = reprs[r_num]
         if repr == nil then return nil end
         local line = repr()
         if line ~= nil then
            return line
         else
            r_num = r_num + 1
            _nextLine()
         end
      end
   end
   return _nextLine
end

function Rainbuf._lineGen(rainbuf, rows)
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
      if cursor < rows then
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






local function new(res)
   if type(res) == "table" and res.idEst == Rainbuf then
      error "made a Rainbuf from a Rainbuf"
   end
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
