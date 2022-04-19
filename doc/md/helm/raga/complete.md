# Complete

Handles choosing and accepting a suggestion from `suggest`\.

```lua
local table = core.table
local clone, splice = assert(table.clone), assert(table.splice)
local EditBase = require "helm/raga/edit"

local Complete = clone(EditBase, 2)

Complete.name = "complete"
Complete.prompt_char = "💬"
```


### Keymaps

```lua
Complete.default_keymaps = {
   { source = "agents.suggest", name = "keymap_selection" },
   { source = "agents.suggest", name = "keymap_actions"}
}
splice(Complete.default_keymaps, EditBase.default_keymaps)
```


### Complete\.onTxtbufChanged\(modeS\)

Update the suggestion list when the user types something\. Note that this won't
be hit after a paste, or if the character inserted caused an accept, because
we will have already shifted ragas\.

\#todo

```lua
function Complete.onTxtbufChanged(modeS)
   send { to = 'agents.suggest', method = 'update' }
   if send { to = 'agents.suggest', field = 'last_collection' } then
      modeS:agent'suggest':selectFirst()
   else
      modeS:shiftMode("default")
   end
   EditBase.onTxtbufChanged(modeS)
end
```


### Complete\.onCursorChanged\(modeS\)

Any cursor movement drops us out of Complete mode\. Note that
onCursorChanged and onTxtbufChanged are mutually exclusive\-\-this does not
fire on a simple insert\.

```lua
function Complete.onCursorChanged(modeS)
   modeS:shiftMode("default")
   EditBase.onCursorChanged(modeS)
end
```


### Complete\.getCursorPosition\(modeS\)

If a suggestion is selected, adjust the cursor position
to the end of the suggestion\.

```lua
local Point = require "anterm:point"
function Complete.getCursorPosition(modeS)
   local point = EditBase.getCursorPosition(modeS)
   local suggestion = send { to = 'agents.suggest', method = 'selectedItem' }
   local tokens = send { to = 'agents.edit', method = 'tokens' }
   if suggestion then
      for _, tok in ipairs(tokens) do
         if tok.cursor_offset then
            point = point + Point(0, #suggestion - tok.cursor_offset)
            break
         end
      end
   end
   return point
end
```


### Complete\.onShift

Select the first item in the list when entering complete mode\.

```lua
function Complete.onShift(modeS)
   send { to = 'agents.suggest', method = 'selectFirst' }
end
```


### Complete\.onUnshift

Deselect and prod the Txtbuf on exit\.

```lua
function Complete.onUnshift(modeS)
   send { to = 'agents.suggest', method = 'selectNone' }
end
```

```lua
return Complete
```
