# Raga base

Some common functionality for ragas

## Dependencies

```lua
local a         = require "anterm:anterm"

local concat         = assert(table.concat)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)
```

## Categories

These are the broad types of event\.

```lua
local RagaBase_meta = {}
local RagaBase = setmetatable({}, RagaBase_meta)

for _, cat in ipairs{"NAV", "CTRL", "ALT", "ASCII",
                     "UTF8", "PASTE", "MOUSE", "NYI"} do
   RagaBase[cat] = {}
end
```

When creating a new raga, remember to set:

```lua-example
RagaBase.name = "raga_base"
RagaBase.prompt_char = "$"
```

## \_\_call \(main input handling/dispatch\)

Looks up and executes a handler for a seq\. Note that we must perform the
lookup on the table that was actually called in order to support inheritance,
e\.g\. an explicit call to `EditBase(modeS, category, value)` when
modeS\.raga == Nerf\.

```lua

local hasfield, iscallable = import("core/table", "hasfield", "iscallable")

function RagaBase_meta.__call(raga, modeS, category, value)
   -- Dispatch on value if possible
   if hasfield(raga[category], value) then
      raga[category][value](modeS, category, value)
   -- Or on category if the whole category is callable
   elseif iscallable(raga[category]) then
      raga[category](modeS, category, value)
   -- Otherwise indicate that we didn't know what to do with the input
   else
      return false
   end
   return true
end

```

## Events

### <Raga>\.onTxtbufChanged\(modeS\)

Called whenever the txtbuf's contents have changed while processing a seq\.

```lua
function RagaBase.onTxtbufChanged(modeS)
   return
end
```

### <Raga>\.onCursorChanged\(modeS\)

Called whenever the cursor has moved while processing a seq\.
Both onTxtbufChanged and onCursorChanged will be called in the
common case of a simple insertion\.

```lua
function RagaBase.onCursorChanged(modeS)
   return
end
```

### <Raga>\.onShift\(modeS\)

Called when first switching to the raga\. Provides an opportunity to
reconfigure zones or perform other set\-up work\.

```lua
function RagaBase.onShift(modeS)
   return
end
```

### <Raga>\.onUnshift\(modeS\)

Opposite of onShift\-\-called when switching away to another raga\.

```lua
function RagaBase.onUnshift(modeS)
   return
end
```

```lua
return RagaBase
```