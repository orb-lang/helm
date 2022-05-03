# Page

`page` is our equivalent of `less`, used for displaying help files and the like\.

```lua
local table = core.table
local clone = assert(table.clone)
local RagaBase = require "helm:raga/base"
```

```lua
local Page = clone(RagaBase, 2)

Page.name = "page"
Page.prompt_char = "❓"
Page.keymap = require "helm:keymap/page"
Page.target = "agents.pager"
```


## Events

We basically ignore the majority of the zones and use the popup zone instead\.
Show and hide it automatically when we shift/unshift\.

```lua
function Page.onShift()
   send { to = "zones.popup", method = "show" }
end
function Page.onUnshift()
   send { to = "zones.popup", method = "hide" }
end
```

```lua
return Page
```