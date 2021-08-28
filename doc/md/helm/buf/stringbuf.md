# Stringbuf

A ``Stringbuf`` is a degenerate ``Rainbuf`` which simply regurgitates a string
one line at a time.

#todo Or maybe we should be slightly less degenerate and perform#### Stringbuf metatable

```lua
local Rainbuf = require "helm:buf/rainbuf"
local Stringbuf = Rainbuf:inherit()
```
## Methods


### Stringbuf:initComposition(), :clearCaches()

Similar to Sessionbuf we dynamically assign our ``_composeOneLine`` function,
however ours is vastly simpler.

```lua
function Stringbuf.clearCaches(buf)
   buf:super"clearCaches"()
   buf._composeOneLine = nil
end

local lines = assert(require "core:string" . lines)
function Stringbuf.initComposition(buf)
   buf._composeOneLine = buf._composeOneLine or lines(buf:value())
end
```
```lua
local Stringbuf_class = setmetatable({}, Stringbuf)
Stringbuf.idEst = Stringbuf_class

return Stringbuf_class
```
