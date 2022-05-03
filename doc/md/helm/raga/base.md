# Raga base

Some common functionality for ragas\.


#### imports

```lua
local a         = require "anterm:anterm"

local concat         = assert(table.concat)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)
```

```lua
local RagaBase_meta = {}
local RagaBase = setmetatable({}, RagaBase_meta)
```

When creating a new raga, remember to set:

```lua-example
RagaBase.name = "raga_base"
RagaBase.prompt_char = "$"
```


## <Raga>\.getCursorPosition\(\)

Computes and returns the position for the terminal cursor,
or nil if it should be hidden\. This is a reasonable default
as not all ragas need the cursor shown\.

```lua
function RagaBase.getCursorPosition()
   return nil
end
```


## Events


### <Raga>\.onTxtbufChanged\(\)

Called whenever the txtbuf's contents have changed while processing a seq\.

```lua
function RagaBase.onTxtbufChanged()
   return
end
```


### <Raga>\.onCursorChanged\(\)

Called whenever the cursor has moved while processing a seq\.
Both onTxtbufChanged and onCursorChanged will be called in the
common case of a simple insertion\.

```lua
function RagaBase.onCursorChanged()
   return
end
```


### <Raga>\.onShift\(\)

Called when first switching to the raga\. Provides an opportunity to
reconfigure zones or perform other set\-up work\.

```lua
function RagaBase.onShift()
   return
end
```


### <Raga>\.onUnshift\(\)

Opposite of onShift\-\-called when switching away to another raga\.

```lua
function RagaBase.onUnshift()
   return
end
```


```lua
return RagaBase
```
