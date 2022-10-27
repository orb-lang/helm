# Agent base class


  An Agent is a sort of [Actor](https://gitlab.com/special-circumstance//actor/-/blob/trunk/doc/md/.md), specifically, one responsible for
a certain sort of data\.

This is called the topic\.  An Agent is specific to a particular sort of topic\.
It may or may not be responsible for many cases of this sort of data, but
always has up\-to\-one example of it on the `.topic` slot\.

The topic may itself be compound, in which case, the Agent will have one
sub\-Agent for each *sort* of subtopic\.

It's important to consider the topic to be logically singular, while keeping
in mind that this is independant of the implementation\.

There is a distinction between the topic changing, and a change of topic\. As
an example, editing a line produces changes in the topic, while loading a new
line changes the topic itself\.  To avoid issues, we call the former mutation
of the topic\.

It's worth stressing that this 'mutation' is not dependent on either the
state of the `.topic` field being mutably changed, nor is a topic change
*logically* connected to the value of the `.topic` field changing\.  It's a
good idea for a change in the object identity of the `.topic` field to always
mean a change in the topic, but this is **not** required\.

An Agent tracks topic mutation by version, answering `:version()` with this
number\.  A change of topic sets the version to `1`, and the version is `0`
when the Agent has no topic\.

The version is **not** a part of the topic, but rather, how many times the topic
has mutated since it was added\.  How this number is stored and derived is
specific to the Agent; broadly speaking, it should be the `.v` field of the
Agent unless there's reason to do otherwise\.

Before discussing the topic in detail, I want to observe that the topic itself
is by no means the whole state of a given Agent\.


### Topic

Topics range from the text printed at the top of helm, to a session review,
itself containing multiple subtopics\.

Topics are:

  - Stateful:  The topic primarily represents the instant state of a given
      collection of data\.  Plenty of things have history, and this
      may be stored within the topic, or by the Agent, in the
      database, or some combination of these\.

  - Data:  But not plain\-old\-data\.  Topics are encouraged to have whatever
      metamethods are useful for working with the data\.  It's also fine
      for the topic to be a bare table, or a string, or anything but a
      function or thread, in principle\.

      Very much unlike Actors of any sort, topics can be passed around\.
      This poses the familiar risk of action\-at\-a\-distance, and we do
      want to take some of the opportunities available to mitigate this,
      just not all of them\.

  - Movable:  Agents, being Actors, participate in the message passing system\.
      They have the specific message `:move`, which sends the topic
      in a Message, setting `.topic` to `nil` and the version to `0`\.

      This covers cases like run review, where the topic is some sort
      of Riff, which needs to be evaluated, with all that entails\.



#### imports

```lua
local core = require "qor:core"
local table = core.table

local cluster = require "cluster:cluster"
local Actor = require "actor:actor"

local Window = require "window:window"
local Deque = require "deque:deque"
local Message = require "actor:message"
```


### Agent\(\)

Agents are generally constructed with no parameters, as part of initializing
Maestro, with actual data supplied in a subsequent `:update()`\.

```lua
local new, Agent, Agent_M = cluster.genus(Actor)

cluster.extendbuilder(new, function(_new, agent)
   agent.buffer_commands = Deque()
   return agent
end)
```


### Agent:version\(\) \#NYI

  Answers the version of the topic\.  This is `0` when the Agent has no topic,
`1` for a fresh topic, monotonically increasing thereafter\.


### Agent:move\(msg\) \#NYI

  Moves the topic by placing it in the payload of the message, settiong the
version to `0` and `.topic` to `nil`\.


### Agent:checkTouched\(\)

\#deprecated
agent\.

More to the point, we handle this sort of change\-management through different
mechanisms\.

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
own details, using `.mergeWindowConfig()` to include the superclass' config\.
\(Note that this is not a method, just a function\.\)

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


```lua
return new
```
