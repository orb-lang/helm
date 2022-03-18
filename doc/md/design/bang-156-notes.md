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


#### Remaining chunks of keymap'd functions to move out of ragas:

1. Eval \(nerf\)

2. History navigation \(nerf\)

3. Quit\-helm handlers \(mostly inherited, review is different\)

4. Restart session \(this is on modeS, but that still seems wrong\),
   eval\-from\-cursor \(which should clearly go in the same place and that may
   **not** be the same as eval\-in\-general\)

5. Open help, derp


#### Plus the non\-keymap'd, event\-y functions:

1. on\[Un\]Shift

2. onTxtbufChanged, onCursorChanged

3. getCursorPosition, which is really the odd man out and should probably move
   to **Rainbuf** in conjunction with a concept of focus \(so we know which
   Rainbuf to ask\)


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
   local line = action 'get-target-subject-as-string'
   -- or just:
   --  target:subjectAsString()
   --
   local success, results = action('evaluate-lua-chunk', line)
   if not success then
      action('error-on-evaluation', results, success)
   else
      action('success-on-evaluation', results, success)
   end
end
```


#### Action messages and handler registry

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
`evaluate-target`, but rather `evaluate-edit-contents-check-for-more-data-append-historian-update-results-clear-edit-contents`\.

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

This is sort of like an "event", and maybe these are in fact separate
concepts, but I don't think so\.  Actions are handled by calling registered
handlers in a specific order, they don't reify "something happening"\.

Let's look at this:

```lua
function Nerf.onCursorChanged(modeS)
   modeS:agent'suggest':update()
   EditBase.onCursorChanged(modeS)
end
```

For one thing Nerf can't know how to do this, and it isn't the right place for
the logic to live\. So the EditAgent yields an `edit-cursor-changed` action\.
SuggestAgent has registered a handler for the first line\.

The second line passes the message, the hard way, to EditBase, which silently
inherits it from RagaBase, which then does nothing\.  This is\.\.\. bad\.  All of
that logic needs to be responsive, any of those steps could break silently or
could be forgotten in refactoring or changing things\.

The handler registry might turn out to be something which shifts when Maestro
shifts, that's unclear right now\.


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

An example: an up\-arrow should turn into the action `cursor-up`, which vril
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


## comments on the coroutine loop

Let's look at it:

```lua
local dispatchmessage = assert(require "actor:actor" . dispatchmessage)
function ModeS.processMessagesWhile(modeS, fn)
   local coro = create(fn)
   local msg_ret = { n = 0 }
   local ok, msg
   local function _dispatchCurrentMessage()
      return pack(dispatchmessage(modeS, msg))
   end
   while true do
      ok, msg = resume(coro, unpack(msg_ret))
      if not ok then
         error(msg .. "\nIn coro:\n" .. debug.traceback(coro))
      elseif status(coro) == "dead" then
         -- End of body function, pass through the return value
         -- #todo returning the command that was executed like this is likely
         -- to be insufficient very soon, work out something else
         return msg
      end
      msg_ret = modeS:processMessagesWhile(_dispatchCurrentMessage)
   end
end
```

First problem is this creates a fresh coroutine for every call, and I can't
see a good reason for that, it could probably just be
`ok, msg_ret = resume(coro, pack(dispatchmessage(modeS, msg)))`\.

D\.S\. no, that's actually important, because sometimes the message being
processed wants to send more messages, so the processing of it needs to be in
a coroutine or those yields will blow up\. I do find this distasteful, but I
haven't thought of a way around it so far\.

The second problem is that the actual activity relies on a function which
isn't defined here, and you have to hunt that function down in two places,
the big one:

```lua
function ModeS.shiftMode(modeS, raga_name)
   modeS:processMessagesWhile(function()
      if raga_name == "default" then
         raga_name = modeS.raga_default
      end
      -- Stash the current lexer associated with the current raga
      -- Currently we never change the lexer separate from the raga,
      -- but this will change when we start supporting multiple languages
      -- Guard against nil raga or lexer during startup
      if modeS.raga then
         modeS.raga.onUnshift(modeS)
         modeS.closet[modeS.raga.name].lex = modeS:agent'edit'.lex
      end
      -- Switch in the new raga and associated lexer
      modeS.raga = modeS.closet[raga_name].raga
      modeS:agent'edit':setLexer(modeS.closet[raga_name].lex)
      modeS.raga.onShift(modeS)
      -- #todo feels wrong to do this here, like it's something the raga
      -- should handle, but onShift feels kinda like it "doesn't inherit",
      -- like it's not something you should actually super-send, so there's
      -- not one good place to do this.
      modeS:agent'prompt':update(modeS.raga.prompt_char)
   end)
   return modeS
end
```

and this one, tucked away inside of `:act`

```lua
function ModeS.act(modeS, event)
   local command
   repeat
      modeS.action_complete = true
      -- The raga may set action_complete to false to cause the command
      -- to be re-processed, most likely after a mode-switch
      local commandThisTime = modeS:processMessagesWhile(function()
         return modeS.maestro:dispatch(event)
      end)
      command = command or commandThisTime
   until modeS.action_complete == true
   if not command then
      command = 'NYI'
   end
   -- Inform the input-echo agent of what just happened
   -- #todo Maestro can do this once action_complete goes away
   modeS:agent'input_echo':update(event, command)
   -- Reflow in case command height has changed. Includes a paint.
   -- Don't allow errors encountered here to break this entire
   -- event-loop iteration, otherwise we become unable to quit if
   -- there's a paint error.
   local success, err = xpcall(modeS.reflow, debug.traceback, modeS)
   if not success then
      io.stderr:write(err, "\n")
      io.stderr:flush()
   end
   collectgarbage()
   return modeS
end
```

It's too hard to follow, methods shouldn't be taking functions which define
all the important things which they do\.

What would fix this I'm thinking, is to make all of `:act` into the message
processing coroutine function at build time \(we only need the one coroutine\)
and wrap/curry it into `:act`\. That way anything else, `:shiftMode` in
particular, can yield and resume messages at any point\.

D\.S\. I\.\.\.don't think I get what you have a problem with\. See my note above, I
don't think one coroutine is enough, though I share your distate for creating
so many of them\. That said, it 
would
 be possible to replace the separate
handling in :shiftMode with expanding the scope in :act so it wraps
everything, and that's probably smart\-\-who knows, maybe someday
`InputEchoAgent:update` will want to message somebody, which right now would
break but obviously 
should
 work\.

We almost certainly want Maestro to have an inner coroutine, which throws to
the outer one, but we can work around that for awhile\.


### Conclusion

This is a sort of unfocused brain dump and it will take some doing to get the
pieces to really gel\.

The early actions are clear, at least to me, and we should do a phone call
that results in issues out of this document, revisit anything which doesn't
make a direct action once those are out of the way\.