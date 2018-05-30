
























































































local Linebuf = require "linebuf"
local byte = assert(string.byte)

local Rainbuf = meta {}








local function new(linebuf)
   local rainbuf = meta(Rainbuf)
   local disp = {}
   rainbuf.disp = disp
   if type(linebuf) == "string" then
      linebuf = Linebuf(linebuf)
   elseif type(linebuf) == "table" then
      if linebuf.idEst == Linebuf then
         _from_linebuf(rainbuf, linebuf)
      else
         for i,v in ipairs(linebuf) do
            if type(v) == "string" then
               rainbuf[i] = v
               if byte(v) == 0x1b then
                  disp[i] = 0
               else
                  disp[i] = v
               end
            else
               error("content of table in Rainbuf must be strings")
            end
         end
      end
   end
   return rainbuf
end
Rainbuf.idEst = new










return new
