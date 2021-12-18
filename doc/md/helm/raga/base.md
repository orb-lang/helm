# Raga base

Some common functionality for ragas\.


#### imports

```lua
local a         = require "anterm:anterm"

local concat         = assert(table.concat)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)
local yield = assert(coroutine.yield)
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


## Communication shorthand

You can always use \`yield\` directly to send messages via \`modeS\`, but there
are some things that are common and have the same structure every time, so
it's worth having helper functions for them\.


### Raga\.agentMessage\(agent\_name, method\_name, args\.\.\.\)

\#todo
central location\.

```lua
local agent_message = {}
_Bridge.agent_message = agent_message

function RagaBase.agentMessage(agent_name, method_name, ...)
   local msg = pack(...)
   msg.method = method_name
   msg = { method = 'agent', n = 1, agent_name, message = msg }
   table.insert(agent_message, msg)
   return yield(msg)
end
```


### Raga\.shiftMode\(raga\_name\)

\#todo
central location\.

```lua
function RagaBase.shiftMode(raga_name)
   return yield{ method = "shiftMode", n = 1, raga_name }
end
```


## Keymaps

We start by including an "extra commands" keymap which other Ragas can simply
add to rather than creating additional keymaps of their own\. However,
substantial logical groupings of bindings should still get their own keymap\.

```lua
RagaBase.default_keymaps = {
   { source = "modeS.raga", name = "keymap_extra_commands" }
}
```


### Default quit handler

We default to having ^Q perform an immediate quit\-\-some ragas may wish to
prompt to save changes or the like first\.

```lua
function RagaBase.quitHelm()
   -- #todo it's obviously terrible to have code specific to a particular
   -- piece of functionality in an abstract class like this.
   -- To do this right, we probably need a proper raga stack. Then -n could
   -- push the Review raga onto the bottom of the stack, then Nerf. Quit
   -- at this point would be the result of the raga stack being empty,
   -- rather than an explicitly-invoked command, and Ctrl-Q would just pop
   -- the current raga. Though, a Ctrl-Q from e.g. Search would still want
   -- to actually quit, so it's not quite that simple...
   -- Anyway. Also, don't bother saving the session if it has no premises...
   if _Bridge.args.new_session then
      local session = yield{ sendto = "hist", property = "session" }
      if #session > 0 then
         -- #todo Add the ability to change accepted status of
         -- the whole session to the review interface
         session.accepted = true
         -- Also, it's horribly hacky to change the "default" raga, but it's
         -- the only way to make Modal work properly. A proper raga stack
         -- would *definitely* fix this
         yield{ method = "setDefaultMode", n = 1, "review" }
         RagaBase.shiftMode "review"
         return
      end
   end
   yield{ method = "quit" }
end

RagaBase.keymap_extra_commands = {
   ["C-q"] = "quitHelm"
}
```


## <Raga>\.getCursorPosition\(modeS\)

Computes and returns the position for the terminal cursor,
or nil if it should be hidden\. This is a reasonable default
as not all ragas need the cursor shown\.

```lua
function RagaBase.getCursorPosition(modeS)
   return nil
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
