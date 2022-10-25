







local core = require "qor:core"
local string = core.string
local lineGen = assert(require "repr:repr" . lineGen)






local Rainbuf = require "helm:buf/rainbuf"
local Resbuf = core.cluster.meta(getmetatable(Rainbuf))












local clear = assert(table.clear)
function Resbuf.clearCaches(resbuf)
   Rainbuf.clearCaches(resbuf)
   resbuf.reprs = nil
   resbuf.r_num = nil
end








local lines = assert(string.lines)
function Resbuf.initComposition(resbuf)
   if not resbuf.reprs then
      resbuf.reprs = {}
      resbuf.r_num = 1
      local value = resbuf:value()
      assert(value.n, "must have n")
      for i = 1, value.n do
         resbuf.reprs[i] = resbuf.frozen
            and lines(value[i])
            or lineGen(value[i], resbuf:contentCols())
      end
   end
end









Resbuf.null_value = { n = 0 }

function Resbuf._init(resbuf)
   Rainbuf._init(resbuf)
   if type(resbuf:value()) ~= "table" then
      (require "status:status")():chat("Expected result table, got " .. (require "repr:repr").ts(resbuf:value()))
   end
   resbuf.frozen = resbuf:value().error
end









function Resbuf._composeOneLine(resbuf)
   assert(resbuf.r_num,
      "r_num has been niled (missing an :initComposition after :clearCaches?)")
   while resbuf.r_num <= #resbuf.reprs do
      local line = resbuf.reprs[resbuf.r_num]()
      if line then
         return line
      end
      resbuf.r_num = resbuf.r_num + 1
   end
   return nil
end




return core.cluster.constructor(Resbuf)

