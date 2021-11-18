# Agent base class

An Agent is a particular kind of [Actor](httk://) which is responsible for
implementing responses to input events, and drives a region of the screen by
providing a [Window](https://gitlab.com/special-circumstance/helm/-/blob/trunk/doc/md/window.md) that is the `source` for a
[Rainbuf](https://gitlab.com/special-circumstance/helm/-/blob/trunk/doc/md/buf/rainbuf.md)\.


#### imports

```lua
local Window = require "window:window"
local Deque = require "deque:deque"
local yield = assert(coroutine.yield)
```


```lua
local meta = assert(require "core:cluster" . Meta)
local Agent = meta {}
```


### Agent:checkTouched\(\)

\#deprecated

```lua
function Agent.checkTouched(agent)
   local touched = agent.touched
   agent.touched = false
   return touched
end
```


### Agent:bufferCommand\(name, args\.\.\.\)

Queues a message to be processed by our associated Rainbuf\.

```lua
function Agent.bufferCommand(agent, name, ...)
   local msg = pack(...)
   msg.method = name
   agent.buffer_commands:push(msg)
end
```


### Agent:agentMessage\(other\_agent\_name, method\_name, args\.\.\.\)

Dispatches a message \(via a `yield` to modeS\) to one of our fellow Agents and
answers the return value\.

\#todo
Agent\. Where should it go?

```lua
function Agent.agentMessage(agent, other_agent_name, method_name, ...)
   local msg = pack(...)
   msg.method = method_name
   msg = { method = 'agent', n = 1, other_agent_name, message = msg }
   return yield(msg)
end
```


### Agent:shiftMode\(raga\_name\)

Shorthand to ask ModeS to switch ragas\.

\#todo
as well\-\-should be in a central location\.

```lua
function Agent.shiftMode(agent, raga_name)
   return yield{ method = "shiftMode", n = 1, raga_name }
end
```


### Agent:contentsChanged\(\)

Notify the Agent \(and associated buffer\) that its contents have changed in
some way\. The buffer needs to clear caches as well as the zone needing a
repaint\.

```lua
function Agent.contentsChanged(agent)
   agent.touched = true -- #deprecated
   agent:bufferCommand("clearCaches")
end
```


### Agent:bufferValue\(\)

Abstract method\. Return the primary value which should be displayed in the
Rainbuf associated with this Agent\.


### Scrolling methods

We forward any scrolling messages that Rainbuf understands as queued commands\.
\#todo
this the only place it'll come up, in which case it's probably fine?

```lua
for _, scroll_fn in ipairs{
   "scrollTo", "scrollBy",
   "scrollUp", "scrollDown",
   "pageUp", "pageDown",
   "halfPageUp", "halfPageDown",
   "scrollToTop", "scrollToBottom",
   "ensureVisible"
} do
   Agent[scroll_fn] = function(agent, ...)
      agent:bufferCommand(scroll_fn, ...)
   end
end
```


#### Agent:evtScrollUp\(evt\), :evtScrollDown\(evt\)

Translate the num\_lines property on a merged scroll event, or scrolls by one
line for key events\.

```lua
function Agent.evtScrollUp(agent, evt)
   agent:scrollUp(evt.num_lines)
end
function Agent.evtScrollDown(agent, evt)
   agent:scrollDown(evt.num_lines)
end
```


### Keymaps

Provide basic scrolling commands at this level, if the raga chooses to include
this keymap\. Note that higher\-priority keymaps may override some of this, e\.g\.
up/down move the cursor when editing text even though the ResultsAgent would
happily process them\.

```lua
Agent.keymap_scrolling = {
   SCROLL_UP   = { method = "evtScrollUp",   n = 1 },
   SCROLL_DOWN = { method = "evtScrollDown", n = 1 },
   UP          = "scrollUp",
   ["S-UP"]    = "scrollUp",
   DOWN        = "scrollDown",
   ["S-DOWN"]  = "scrollDown",
   PAGE_UP     = "pageUp",
   PAGE_DOWN   = "pageDown",
   HOME        = "scrollToTop",
   END         = "scrollToBottom"
}
```

### Agent:window\(\), :windowConfiguration\(\)

The `Window`s of `Agent`s need to implement some common behavior in order to
interact correctly with `Rainbuf`s and change detection, so we start with a
basic config\. Subclasses may override `:windowConfiguration()` to add their
own details, using `.mergeWindowConfig()` to include the superclass' config\.
\(Note that this is not a method, just a function\.\)

```lua
local addall = assert(require "core:table" . addall)
function Agent.mergeWindowConfig(cfg_a, cfg_b)
   for cat, props in pairs(cfg_b) do
      cfg_a[cat] = cfg_a[cat] or {}
      addall(cfg_a[cat], props)
   end
   return cfg_a
end

function Agent.windowConfiguration(agent)
   return {
      field = { touched = true },
      fn = {
         buffer_value = function(agent, window, field)
            return agent:bufferValue()
         end,
         commands = function(agent, window, field)
            return agent.buffer_commands
         end
      },
      closure = { checkTouched = true }
   }
end

function Agent.window(agent)
   return Window(agent, agent:windowConfiguration())
end
```


### Agent\(\)

At the moment, Agents are generally constructed with no parameters, and any
needed values are filled in later\. Some do need to set up some initial state,
so we provide an `_init` method\. \#todo should we in fact have some arguments
to the constructor?

```lua
function Agent._init(agent)
   agent.buffer_commands = Deque()
end

function Agent.__call(agent_class)
   local agent_M = getmetatable(agent_class)
   local agent = setmetatable({}, agent_M)
   agent:_init()
   return agent
end
```


```lua
local constructor = assert(require "core:cluster" . constructor)
return constructor(Agent)
```
