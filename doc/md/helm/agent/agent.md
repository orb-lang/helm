# Agent base class

An Agent is a particular kind of [Actor](httk://) which is responsible for
implementing responses to input events, and drives a region of the screen by
providing a [Window](NO default.domain IN MANIFESThelm/MISSING_POST_PROJECTdoc/md/window.md) that is the `source` for a
[Rainbuf](NO default.domain IN MANIFESThelm/MISSING_POST_PROJECTdoc/md/buf/rainbuf.md)\.


#### imports

```lua
local Window = require "window:window"
local Deque = require "deque:deque"
local Message = require "actor:message"

local table = core.table
```


```lua
local Agent = meta {}
```


#### Agent:send\(msg\)

Sends a message to the Agent's boss\.

```lua
local coro = assert(core.thread.nest 'actor')
local yield = assert(coro.yield)

function Agent.send(agent, msg)
   return yield(Message(msg))
end
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


### Agent:window\(\), :windowConfiguration\(\)

The `Window`s of `Agent`s need to implement some common behavior in order to
interact correctly with `Rainbuf`s and change detection, so we start with a
basic config\. Subclasses may override `:windowConfiguration()` to add their
own details, using `.mergeWindowConfig()` to include the superclass' config\.Note that this is not a method, just a function\.\)

\(
```lua
local addall = assert(table.addall)
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
return core.cluster.constructor(Agent)
```
