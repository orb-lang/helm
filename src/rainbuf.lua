
























































































local Txtbuf = require "txtbuf"
local byte = assert(string.byte)

local Rainbuf = meta {}








local function new(txtbuf)
   local rainbuf = meta(Rainbuf)
   local disp = {}
   rainbuf.disp = disp
   if type(txtbuf) == "string" then
      txtbuf = Txtbuf(txtbuf)
   elseif type(txtbuf) == "table" then
      if txtbuf.idEst == Txtbuf then
         _from_txtbuf(rainbuf, txtbuf)
      else
         for i,v in ipairs(txtbuf) do
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
