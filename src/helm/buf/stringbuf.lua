











local core = require "qor:core"
local string = core.string

local Rainbuf = require "helm:buf/rainbuf"
local Stringbuf = core.cluster.meta(getmetatable(Rainbuf))












function Stringbuf.clearCaches(buf)
   Rainbuf.clearCaches(buf)
   buf._composeOneLine = nil
end

local lines = assert(string.lines)
function Stringbuf.initComposition(buf)
   buf._composeOneLine = buf._composeOneLine or lines(buf:value())
end




return core.cluster.constructor(Stringbuf)

