# Notes on \!156


  First observation is that the back end of the architecture is basically
solid, and that since the goal was specifically "eliminate the old code paths
while modifying everything else as little as possible", some of what I'm
putting into this document was already anticipated\.

What we have right now is a control flow based on a structure in which various
instances were passed around by handle and acted upon, and now we have the
same control flow with everything replaced by messages\.

I'm going to do a few subheadings which can be rolled into issues once we've
had a chance to discuss them\.


#### Only yield Messages, directly

  This is the first step in grasping the current control flow\.  I get the
point in adding the shorthand functions, but this isn't the final form of the
codebase and we want to be able to see the messages where they're sent\.

For an example, I was able to produce this diff:

```txt
> local line = send { sendto = "maestro.agents.edit",
>                         method = 'contents' }
<     local line = yieldMessage {'edit',
<                                 method = 'agent',
<                                 message = { method = 'contents'} }
```

Just unrolling the agentMessage, because the method "agent" itself is an
artifact of long call chains which we ultimately don't want to have\.

This is also improved by adding `.n` during Message construction, while
verifying the structure is correct\.  It also makes any sub\-Messages it
encounters into a Message, out of the literal table\.

One of the advantages of this architecture: it doesn't matter at all where one
of these messages is being sent from, as long as we know the receiver \(and I
have extensions in mind for when we don't\)\.



#### Separate keystroke resolution completely from action

Note: it's not clear to me that "raga" is going to remain a useful concept in
the new architecture, but it's what we have, so I'll stick with it for now\.

Ragas need to answer an input with an action, or throw it if they need
information from the display layer to derive an action\.

These have to be completely decoupled, and the next step after unrolling
messages is to just create a big library for every action that a Raga can
perform, and have the Ragas themselves just be keymaps with fall\-throughs\.

So it's fine to have functions in the Raga and a Raga constructor, but the
intelligence has to serve turning an input sequence into an action\.

For immediate purposes this is almost book\-keeping, just move all functions
that aren't resolving keymaps out of the Ragas, and look them up from the
return value of the Raga\.

Since everything is a message right now, basically, it shouldn't matter where
these functions get called from\.


## Next steps

  This isn't the final form, but it should make what we have right now make
sufficient sense\.

The flow is basically this, minus some feedback loops:


- Input event is:

 - looked up on the current composed raga, returning a `kebab-case` string

 - this is looked up against one big library \(if we have non\-unique names, add
     more kebabs to the shish\), and is a function

 - the function just sends a bunch of messages, whatever happens happens,
     coroutine loop

 - paint

This will work, and we can extend it, just send more messages to more stuff\.

It's not the final form, and isn't intended to be\.  This doesn't actually
decomplect the various components, although it's given us a good separation
between the back and the presentation layer, and it will give us a good
separation between keystroke mapping and actions\.


### Move as much as possible to Agents

The Ragas have two problems right now: they have a bunch of functions in them
and those functions do things which should be done directly by Agents\.

The first step is to get all the functions out, and just do the same thing
with them after pulling them out of a big old library\.

Searching the string `function ` in the raga directory turns up 42 instances,
which overestimates how many need moving, but not by much\.

Anything which we can move to the Agents, we should, because the next step
relies on that\.  Everything else will just be a series of messages, because
they won't be receiving any instance tables to call methods on\.


### Turn Messages into Actions where possible

Right now, the biggest difference between just calling a method, and sending a
message which is "call this method", is that the latter is harder, and messes
up the call stack for no real benefit\.

What we need to build out of it is something which is composable, scalable,
and where the components don't know or care whether they're in `helm` or
precisely where in `helm` they might be, except when they need to\.


### Next concept set

We've done well adding Messages, although we're only seeing one benefit: we
don't have to pass anything around anymore, and if we had a method like,
I dunno, `historian.wipeDatabase`, we wouldn't **have** to expose that method
to `dispatchmessage`\.

Maestro and the Agents are correctly placed, and the latter are doing, mostly,
what they should be doing\.

Right now, Maestro is mostly just standing between `modeS` and the various
Agents\.  That's the correct place for it to be, but it's expected to do more,
and we'll cover what that is\.

The Agent\-Window pairing is working fine, from what I see\.  Agents are missing
a concept \(the subject, see below\) and I see some keymaps hanging out in the
Agent base class, which is part of what we need to strictly segregate: an
Agent should never see an input event in raw form\.


#### Actions

Let's take it as gospel that composed keymaps have to return literal data,
no closures\.  We need that property for a few reasons that I don't want to
litigate\.

That return value we're going to call an action\. It can be a string or an
array, so that creating one can be any of

```lua
action "string"
action {"table", "of", 4, "values"}
action("this", "also", "makes", "an array")
```

The former would be `"page-down"`, note that is one \(1\) string and nothing
else, the latter would be something like `{"self-insert", "a"}`\.


### Target

Note what's missing here: any idea of where the action is being applied\. Ragas
don't know this, and they can't: they can use whatever functions they need,
we'll think about actual keymap composition later, but they don't *return*
functions, ever\.  Functions can't be written into a configuration file, so
they can't live in a keymap\.

So once Maestro has the action, it looks this up against its current state,
which has a library\.  Maestro also knows the most important thing to know,
which is the **target**\.  Canonically this is the EditAgent, but if it's the
PagerAgent, then we need to both retrieve different *actions* from keystrokes,
and potentially select different *functions* to realize those actions\.

If the target doesn't want the action, Maestro looks for a **handler** for that
action, which can be any of the Actors\.

Maestro is responsible for composing all of this into the current state, and
as a minimal move in that direction, all mode shifting should move into
Maestro\.

These library functions are implicit methods, with the signature
`fn(target, ...)`\.  They shouldn't actually do much, and should favor taking
sub\-actions over message passing and complected logic\.

Here's the current state of `Nerf.eval`:

```lua
function Nerf.eval()
   local line = send { sendto = "maestro.agents.edit",
                       method = 'contents' }

   local success, results = send { call = "eval", line }

   if not success and results == 'advance' then
      send { sendto = "maestro.agents.edit",
             method = 'endOfText'}
      return false -- Fall through to EditAgent nl binding
   else
      send { sendto = 'hist',
             method = 'append',
             line, results, success }

      send { sendto = 'hist', method = 'toEnd' }

      send { sendto = "maestro.agents.results",
                     method = 'update', results }

      send { sendto = "maestro.agents.edit",
                             method = 'clear' }
   end
end
```

I'm imagining after sufficient factoring, it looks more like this:

```lua
lib['evaluate-target'] = function(target)
   local line = action 'get-target-contents-as-string'
   -- or just:
   --  target:subjectAsString()
   --
   -- =action= can be variadic or just take string-or-table, all three being
   -- the right kind of flexible
   --
   local success, results = action('evaluate-lua-chunk', line)
   if not success then
      action('error-on-evaluation', results, success)
   else
      action('success-on-evaluation', results, success)
   end
end
```





#### Event messages and handler registry

We need to move away from agents telling each other things as much as
possible\.  This is going to call for additional Message fields, probably\.

There is a point to replacing this:

```lua
      send { sendto = 'hist',
             method = 'append',
             line, results, success }

      send { sendto = 'hist', method = 'toEnd' }

      send { sendto = "maestro.agents.results",
                     method = 'update', results }

      send { sendto = "maestro.agents.edit",
                             method = 'clear' }
```

With this

```lua
   action('after-successful-evaluation', results, success)
```

Which is basically that the name for the current `Nerf.eval()` wouldn't be
`evaluate-target`, but rather `evaluate-edit-contents-check-for-more-data` \.\.
`-append-historian-update-results-clear-edit-contents`\.

It's not just that the current function does too much, it's that
`evaluate-target` is genially ignorant of what else the target is, besides
having a `subjectAsString` method to respond to\.

Furthermore, there may not be a `hist`, or a `maestro.agents.results` to
boss around\.

The actual call API is a work in progress, let's consider this compatible but
more explicit version:

```lua
  yield(Message { action = 'after-successful-evaluation', results, success})
```

And I'll continue to work with all Messages landing on `modeS`, even though
we'll probably want to do better than that\.

Modeselektor would immediately pass any action to Maestro anyway, because
Agents get first shot at everything\.

Agents need a concept of being active, and a way to register a borrowmethod
as a response to a given action\.  This will need to be done carefully, because
order is frequently important\.


#### more about the target

It's really the most important missing concept here\. It's the back\-ends answer
to "focus" on the presntation layer, and `helm` *always has one*, already\.
The lack of an explicit target \(which is always one \(1\) Agent\) is holding the
architecture back\.

Part of what's going on here is that `helm` has a bunch of tasty pieces which
are still welded together, and a lot of what is right now in `helm` will end
up in subsidiary projects\.

This is what's driving the firewalls between various component systems: Edit
actions have to stop knowing about the historian, period\.

An example: an up\-arrow should turn into the action `cursor-up`, which vril c
can map to `k`, but the EditAgent shouldn't handle the case where we need to
swap out its `.subject` \(more about that in a moment\), certainly not by
sending a message to the Historian\.

What it should do is send `action "target-cursor-top-clamped"` \(bad name but
it's accurate\.\.\.\) and then \(and you might hate this or love it\) the
**EditAgent** has a handler for that case, which sends
`action "set-previous-page"`\. `modeS` has a handler for this which gets the
line and results from `historian` and puts them as the *subjects* of the
`target` and `resultAgent`, where here the target is `editAgent`\.


#### subjects

  This is also important, and the EditAgent isn't doing it correctly
yet\.  The result agent is pretty close, except that the field called `.result`
should just be `.subject`\.

Every Agent should have a subject, and it needs to be separate from the Agent\.
So for EditAgent, `agent[1]` is `agent.subject[1]`, `agent.cursor` is
`agent.subject.cursor`, and so on\.

The difference is this lets us move subjects between agents, because the
subject itself has an identity table\.
