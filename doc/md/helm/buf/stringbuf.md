# Stringbuf

A `Stringbuf` is a degenerate `Rainbuf` which simply regurgitates a string
one line at a time\.

\#todo
word\-boundary\-aware wrapping? We'll do that if and when we need it\.\.\.


#### Stringbuf metatable

```lua
local Rainbuf = require "helm:buf/rainbuf"
local Stringbuf = meta(getmetatable(Rainbuf))

local string = core.string
```


## Methods


### Stringbuf:initComposition\(\), :clearCaches\(\)

Similar to Reviewbuf we dynamically assign our `_composeOneLine` function,
however ours is vastly simpler\.

```lua
function Stringbuf.clearCaches(buf)
   Rainbuf.clearCaches(buf)
   buf._composeOneLine = nil
end

local lines = assert(string.lines)
function Stringbuf.initComposition(buf)
   buf._composeOneLine = buf._composeOneLine or lines(buf:value())
end
```


```lua
return core.cluster.constructor(Stringbuf)
```
