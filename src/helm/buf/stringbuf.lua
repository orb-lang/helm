











local Rainbuf = require "helm:buf/rainbuf"
local Stringbuf = Rainbuf:inherit()












function Stringbuf.clearCaches(buf)
   buf:super"clearCaches"()
   buf._composeOneLine = nil
end

local lines = assert(require "core:string" . lines)
function Stringbuf.initComposition(buf)
   buf._composeOneLine = buf._composeOneLine or lines(buf:value())
end




local Stringbuf_class = setmetatable({}, Stringbuf)
Stringbuf.idEst = Stringbuf_class

return Stringbuf_class
