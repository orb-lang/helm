







local lineGen = import("repr:repr", "lineGen")
local cluster = require "core:cluster"






local Rainbuf = require "helm:rainbuf"
local Resbuf = Rainbuf:inherit()












local clear = assert(table.clear)
function Resbuf.clearCaches(resbuf)
   resbuf:super"clearCaches"()
   resbuf.reprs = nil
   resbuf.r_num = nil
end








local lines = import("core/string", "lines")
function Resbuf.initComposition(resbuf, cols)
   resbuf:super"initComposition"(cols)
   if not resbuf.reprs then
      resbuf.reprs = {}
      resbuf.r_num = 1
      for i = 1, resbuf.n do
         resbuf.reprs[i] = resbuf.frozen
            and lines(resbuf[i])
            or lineGen(resbuf[i], cols)
      end
   end
end










local max = assert(math.max)
function Resbuf.replace(rainbuf, res)
   if not res then
      res = { n = 0 }
   end
   assert(res.n, "must have n")
   for i = 1, max(rainbuf.n, res.n) do
      rainbuf[i] = res[i]
   end
   rainbuf.n = res.n
end









function Resbuf._composeOneLine(resbuf)
   while resbuf.r_num <= resbuf.n do
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

