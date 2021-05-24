# Resbuf

A `Resbuf` is a `Rainbuf` specialized to displaying REPL results using `repr`\.


#### includes

```lua
local lineGen = import("repr:repr", "lineGen")
local cluster = require "core:cluster"
```


#### Resbuf metatable

```lua
local Rainbuf = require "helm:buf/rainbuf"
local Resbuf = Rainbuf:inherit()
```


## Methods


### Resbuf:clearCaches\(\)

In addition to cached lines, we must clear lineGen iterators and the
index we're working on\.

```lua
local clear = assert(table.clear)
function Resbuf.clearCaches(resbuf)
   resbuf:super"clearCaches"()
   resbuf.reprs = nil
   resbuf.r_num = nil
end
```


### Resbuf:initComposition\(cols\)

Set up the lineGen\(\) iterators we'll use to build our output\.

```lua
local lines = import("core/string", "lines")
function Resbuf.initComposition(resbuf, cols)
   resbuf:super"initComposition"(cols)
   if not resbuf.reprs then
      resbuf.reprs = {}
      resbuf.r_num = 1
      for i = 1, resbuf.n do
         resbuf.reprs[i] = resbuf.frozen
            and lines(resbuf[i])
            or lineGen(resbuf[i], resbuf.cols)
      end
   end
end
```


### Resbuf:replace\(res\)

Replace the contents of the Resbuf with those from res,
emptying it if res is nil\. Note that we need to discard
results we may previously have held, even if res contains fewer\.

```lua
local max = assert(math.max)
function Resbuf.replace(resbuf, res)
   resbuf:super"replace"(res)
   if not res then
      res = { n = 0 }
   end
   assert(res.n, "must have n")
   for i = 1, max(resbuf.n, res.n) do
      resbuf[i] = res[i]
   end
   -- Treat an error result from valiant as just a string,
   -- not something to repr
   resbuf.frozen = res.error
   resbuf.n = res.n
end
```


### Resbuf:\_composeOneLine\(\)

Internal implementation to generate one line of output\. Try to retrieve a line
from the current repr, moving on to the next if that one has run out\.

```lua
function Resbuf._composeOneLine(resbuf)
   assert(resbuf.r_num,
      "r_num has been niled (missing an :initComposition after :clearCaches?)")
   while resbuf.r_num <= resbuf.n do
      local line = resbuf.reprs[resbuf.r_num]()
      if line then
         return line
      end
      resbuf.r_num = resbuf.r_num + 1
   end
   return nil
end
```


```lua
local Resbuf_class = setmetatable({}, Resbuf)
Resbuf.idEst = Resbuf_class

return Resbuf_class
```
