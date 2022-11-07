# Resbuf

A `Resbuf` is a `Rainbuf` specialized to displaying REPL results using `repr`\.


#### imports

```lua
local core = require "qor:core"
local string = core.string
local lineGen = assert(require "repr:repr" . lineGen)
```


#### Resbuf metatable

```lua
local Rainbuf = require "helm:buf/rainbuf"
local Resbuf = core.cluster.meta(getmetatable(Rainbuf))
```


## Methods


### Resbuf:clearCaches\(\)

In addition to cached lines, we must clear lineGen iterators and the
index we're working on\.

```lua
local clear = assert(table.clear)
function Resbuf.clearCaches(resbuf)
   Rainbuf.clearCaches(resbuf)
   resbuf.reprs = nil
   resbuf.r_num = nil
end
```


### Resbuf:initComposition\(cols\)

Set up the lineGen\(\) iterators we'll use to build our output\.

```lua
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
```


### Resbuf:\_init\(res\)

Initially set buf\.frozen for error results\. `null_value` can just be a
constant on the metatable, but this seems like a good place to mention it\.

```lua
Resbuf.null_value = { n = 0 }

function Resbuf._init(resbuf)
   Rainbuf._init(resbuf)
   if type(resbuf:value()) ~= "table" then
      (require "status:status")():chat("Expected result table, got " .. (require "repr:repr").ts(resbuf:value()))
   end
   resbuf.frozen = resbuf:value().error
end
```


### Resbuf:\_composeOneLine\(\)

Internal implementation to generate one line of output\. Try to retrieve a line
from the current repr, moving on to the next if that one has run out\.

```lua
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
```


```lua
return core.cluster.constructor(Resbuf)
```
