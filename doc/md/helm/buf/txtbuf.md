# Txtbuf

A `Rainbuf` specialized for displaying editable text, with optional
syntax highlighting\.


## Interface


### Instance fields


-  render\_row : Index of the row being rendered \(Rainbuf implementation detail\)


-  suggestions : The `Window` to the `SuggestAgent`, from which the list of
    active suggestions is available, along with whether it has changed\.


## Methods

```lua
local core = require "qor:core"

local Rainbuf = require "helm:buf/rainbuf"
local Txtbuf = meta(getmetatable(Rainbuf))
```


### Txtbuf:clearCaches\(\)

```lua
function Txtbuf.clearCaches(txtbuf)
   Rainbuf.clearCaches(txtbuf)
   txtbuf.render_row = nil
end
```


### Txtbuf:initComposition\(\)

```lua
function Txtbuf.initComposition(txtbuf)
   txtbuf.render_row = txtbuf.render_row or 1
end
```


#### Txtbuf:\_composeOneLine\(\)

```lua
local c = assert(require "singletons:color" . color)
local concat = assert(table.concat)
function Txtbuf._composeOneLine(txtbuf)
   if txtbuf.render_row > #txtbuf:value() then return nil end
   local tokens = txtbuf.source.tokens(txtbuf.render_row)
   local suggestion = txtbuf.suggestions
      and txtbuf.suggestions:selectedItem()
   for i, tok in ipairs(tokens) do
      -- If suggestions are active and one is highlighted,
      -- display it in grey instead of what the user has typed so far
      -- Note this only applies once Tab has been pressed, as until then
      -- :selectedItem() will be nil
      if suggestion and tok.cursor_offset then
         tokens[i] = txtbuf.suggestions.highlight(suggestion, txtbuf:contentCols(), c)
      else
         tokens[i] = tok:toString(c)
      end
   end
   txtbuf.render_row = txtbuf.render_row + 1
   return concat(tokens)
end
```


### Txtbuf:checkTouched\(\)

We additionally check if something has changed about the active suggestions\.
We must **not** clear the touched flag there in the process, but \#todo THIS WAY
IS BAD, since it depends on us going first, before the suggest zone itself is
checked\.

```lua
function Txtbuf.checkTouched(txtbuf)
   if txtbuf.suggestions and txtbuf.suggestions.touched then
      txtbuf:beTouched()
   end
   return Rainbuf.checkTouched(txtbuf)
end
```


```lua
return core.cluster.constructor(Txtbuf)
```
