











local meta = assert(require "core:cluster" . Meta)
local Rainbuf = require "helm:buf/rainbuf"
local Stringbuf = meta(getmetatable(Rainbuf))












function Stringbuf.clearCaches(buf)
   Rainbuf.clearCaches(buf)
   buf._composeOneLine = nil
end

local lines = assert(require "core:string" . lines)
function Stringbuf.initComposition(buf)
   buf._composeOneLine = buf._composeOneLine or lines(buf:value())
end




local constructor = assert(require "core:cluster" . constructor)
return constructor(Stringbuf)

