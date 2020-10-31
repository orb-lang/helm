# Session review

Raga for reviewing a previously\-saved session\.

```lua
local clone = assert(require "core:table" . clone)
local RagaBase = require "helm:raga/base"
local Txtbuf = require "helm:txtbuf"
local Sessionbuf = require "helm:sessionbuf"
```

```lua
local Review = clone(RagaBase, 2)
Review.name = "review"
Review.prompt_char = "💬"
```

### Review\.onShift\(modeS\)

We use the results area for displaying the lines and results
of the session in a Sessionbuf\.

```lua
function Review.onShift(modeS)
   modeS.zones.results:replace(
      Sessionbuf(modeS.hist.session, { scrollable = true }))
end
```

```lua
return Review
```