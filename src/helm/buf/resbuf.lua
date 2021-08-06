







local lineGen = import("repr:repr", "lineGen")
local cluster = require "core:cluster"






local meta = assert(require "core:cluster" . Meta)
local Rainbuf = require "helm:buf/rainbuf"
local Resbuf = meta(getmetatable(Rainbuf))












local clear = assert(table.clear)
function Resbuf.clearCaches(resbuf)
   resbuf:super"clearCaches"()
   resbuf.reprs = nil
   resbuf.r_num = nil
end








local lines = import("core/string", "lines")
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
   resbuf:super"_init"()
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




local constructor = assert(require "core:cluster" . constructor)
return constructor(Resbuf)

