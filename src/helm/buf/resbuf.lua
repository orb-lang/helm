







local lineGen = import("repr:repr", "lineGen")
local cluster = require "core:cluster"






local Rainbuf = require "helm:buf/rainbuf"
local Resbuf = Rainbuf:inherit()












local clear = assert(table.clear)
function Resbuf.clearCaches(resbuf)
   resbuf:super"clearCaches"()
   resbuf.reprs = nil
   resbuf.r_num = nil
end








local lines = import("core/string", "lines")
local npairs = assert(require "core:table" . npairs)
function Resbuf.initComposition(resbuf)
   if not resbuf.reprs then
      resbuf.reprs = {}
      resbuf.r_num = 1
      for i = 1, resbuf.value.n do
         resbuf.reprs[i] = resbuf.frozen
            and lines(resbuf.value[i])
            or lineGen(resbuf.value[i], resbuf:contentCols())
      end
   end
end










local max = assert(math.max)
function Resbuf.replace(resbuf, res)
   res = res or { n = 0 }
   assert(res.n, "must have n")
   resbuf:super"replace"(res)
   -- Treat an error result from valiant as just a string,
   -- not something to repr
   resbuf.frozen = res.error
end









function Resbuf._composeOneLine(resbuf)
   assert(resbuf.r_num,
      "r_num has been niled (missing an :initComposition after :clearCaches?)")
   while resbuf.r_num <= resbuf.value.n do
      local line = resbuf.reprs[resbuf.r_num]()
      if line then
         return line
      end
      resbuf.r_num = resbuf.r_num + 1
   end
   return nil
end




local Resbuf_class = setmetatable({}, Resbuf)
Resbuf.idEst = Resbuf_class

return Resbuf_class

