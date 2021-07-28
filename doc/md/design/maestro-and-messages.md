# On Maestro and Messages


  We've made good progress in moving helm to an Actor model\.

The goal of the latest feature branch is to cleanly separate all Zone logic
from everything else\.  In service to this, we've defined **Agents**, which are
responsible for manipulating data \(which we call the subject\) on the back end,
and which have **Windows** which provide read access to the subject\.

The Windows are owned by **Buffers** \(Bufs\) which prepare the contents for
display in **Zones**\.

This isn't complete, and won't be 100% when we merge, but it's in good shape\.


## Messages

  In the process, we've realized that some of the agents need to communicate
actions to their associated buffer\.  The simplest example: we've had a field
called `.touched`, which gets checked to paint a buffer to a zone, then
cleared manually\.  This doesn't really express that the flag is *consumed* by
the buffer, and it doesn't give us a general way to check this sort of thing
and reset it in a consistent fashion\.

So we'll move to a queue, which can be peeked and popped through the Window\.

The contents of the queue are messages\.  They can be simple strings, like
replacing `.touched` with `'paint'`, or numbers: the simplest implementation
of scrolling is to queue up enough `1` or `-1` to consume all the scroll
events, or just send them one at a time if we decide to drain the input queue
at one input event per `uv` event\.  Which is the current model, and I don't
see a compelling reason to change it yet\.

It's a good rule to use the simplest implementation we can get away with, and
these particular queues might not need anything more than this\.  We have the
Window for conveying the subject, and if the Agents start telling Bufs to do
complex things, that undermines the goal of having a clean separation between
action logic and display logic\. It doesn't break it completely, we'll get
back to that, but there are plenty of reasons we want to avoid it\.

We do need more complex messages in a couple of places, however, and once we
have them I expect to find more such places\.


### Maestro\-Zoneherd Mailbox

  In a 'normal' action, the relationship of Buffers to Zones doesn't change\.
Sometimes, however, a Buffer is swapped, or a Zone \(canonically the popup\)
becomes visible or invisible\.

Currently, we store the Bufs on whatever Zone displays them, even when they
aren't visible\.  This needs to change\.

I maintain that the best architecture has the Bufs owned by the Zoneherd, and
kept in a mutable table which serves as a state machine for the display\.

This makes the following display logic: the Zoneherd must first adjust any
visibility, by moving Bufs around in the state table\.  It then iterates the
whole Buf collection, looking for any messages on the queue, in an order which
respects the Z plane \(that is, anything which might be printed above other
Zones must be checked last\)\.  Anything which has contents on its queue is
passed as a parameter to a Zone, which will display it accordingly\.

There are also occasions, resizing the terminal being the big one, where
everything needs repainting\.

In any case, we need a queue between the Maestro and the Zoneherd, to send
messages pertaining to \(at least\) visibility\.  We have the [Mailman](https://gitlab.com/special-circumstance/helm/-/blob/trunk/doc/md/mailman/.md), a simple collection of two [Deques](https://gitlab.com/special-circumstance/helm/-/blob/trunk/doc/md/deque/.md)\.

We'll need bidirectional communication here, once we get to mouse clicks\.
Resolving the target of a mouse action needs to be performed by a Zone,
because they know about rows and columns, and can translate that into a
message a Buf can understand; but it takes an Agent to do anything about the
target, since Bufs paint subjects, they don't manipulate them\.

This is a case where we'll need more complex communication than just simple
strings\.  A resizing, for one example, comes with new values for the row and
column, and handling this with `zoneBox:sendAll('resize', 160, 80)` is asking
for trouble\.  This leave us having to accumulate state on read, which is
brittle and precludes any generic dispatch on the Zoneherd side\.

The next simplest scheme would be `zoneBox:send{'resize', 160, 80}`, and this
has some advantages\.  We can naively translate it to something like this:

```lua
receiver[msg[1]](receiver, unpack(msg, 2))
```

Which is in this case equivalent to `zoneherd:resize(160, 80)`\.

It isn't general enough, however\.  A better payload would look more like
`{ method = 'resize', n = 2, 160, 80 }`, which would dispatch as

```lua
local function _dispatchMethod(receiver, msg)
   return receiver[msg.method](receiver, unpack(msg))
end
```

With a parameter order convenient for attaching this function as a method to
any receiver which might use it\.

This is better\.  While methods are going to be commonplace messages \(in
fact we refer to method calls as "passing `widget` the message `:frob`"\),
there's no reason to limit ourselves to this\.


## Rationale

  The important thing we get out of this is Actors taking action within their
own module, in a consistent place\.  We've all traced call stacks to see where
and when an object is getting called, and paged through a few source files to
really trace a piece of logic\.  It's easier to reason about one modules at a
time\.

It also behaves better with user extensions\.  We can, and should, check that
a given Message is asking for something valid before trying to execute it\.

We end up converging around a single dispatch point per message channel, and
this poses an opportunity for a hookable function which can introspect on any
Message an Actor is expected to act upon\.

Between the Agents and Buffers, and between Maestro and Zoneherd, we also
get a cleaner separation of order of execution: the Agents can complete their
job, send as many Messages to the Zones as necessary, and only then do the
Buffers and Zones need to do their work\.

Where Maestro and Zoneherd are concerned, there could be more than one
round of this back\-and\-forth: maestro sends a mouse click to zoneherd, which
returns a specific Target, this is passed to the Agent which e\.g\. collapses
a table in a Result, and Zoneherd is then instructed to paint\.

This is a simple `repeat until` at the end of `modeS:act`, where we first
empty Maestro's `zoneBox`, then call `zone:paint()`, then exit the loop if the
`zoneBox` is \(still\) empty\.  The alternative, of having some way to call
Maestro from the Zoneherd, would be pretty ugly, needing some reentry point
within the Zoneherd instead of just painting again\.

Reified Messages are also extensible, capable of holding more information than
fits in a method call\.  This is in principle open\-ended, and our initial
use of Messages will go beyond what a method call is capable of\.

Last but not least, a carefully\-crafted Message can travel across process
boundaries\.  Of the Lua objects, we can't stream functions, coroutines, orin general\) userdata, but everything else is tractable and I don't envision
those
\( just mentioned being common parameters\.

On our roadmap, using helm in single\-Lua\-state mode won't be the normal form,
and might not even be possible\.  Exactly what that looks like is a
conversation for later, but building an Actor\-Message architecture is a big
part of what makes it possible\.


### Message API

  We'll want a metatable and constructor here, and Messages should be
read\-only after construction\.

The array portion of the Message will be parameters, if any, and `.n` is
always used\.  We may as well make `#msg` return `.n` while we're at it\.


#### fields

  This is inherently open\-ended, in that we can make up a new kind of Message
whenever we need one\.  A message can't *just* be array parameters and `.n`,
that would imply some kind of default method we don't necessarily have\.
`__call`?  That seems awkward, I'd rather that be expressed as
`call = true`\.

For a request for action we need some of:


- method:  Says "receiver, call this method with the provided parameters"\.
    Value is a symbol\.  Without `sendto`, the method is called on the
    receiver itself\.


- sendto:  Because it can't be `for`\.  This says "intended for whatever is
    living on the slot with this name"\.  Combines with `method`,
    `message`, and `call`\.

    In general, an Actor can only act on messages using entities on its
    own slots, so that's explicitly the semantic of `sendto`\.  We'll
    find ourselves needing more general dispatch eventually, with event
    Messages, but `sendto` will always mean "send this to your own slot
    with this name"\.


- message:  Here the value is an entire Message\.  These may be chained to make
    a call arbitrarily deep in nested tables\.


- call:  Value is either `true` or a symbol\.  If a symbol, call the function
    at that slot with the parameters, if `true`, then call the receiver
    with the parameters\.


- n:  Already mentioned, but for completeness, an integer >= 0 which specifies
    the number of parameters in the array portion of the Message\.

This gives us everything we need for an Actor to take action, but it then
needs to reply in many cases, so we need more for that\.

Note that *every* field in the above is optional, because a reply is also a
Message, and a reply doesn't have to come with a request for action, it can
just be an envelope around a payload\.

So we'll need some more fields\.  Here's a tentative list, I expect we'll be
working on this one for awhile to get it right\.


- sender:  A name for the Actor sending the message\.  This has some
    implications, in terms of wanting an Actor base class which knows
    its own name, and can craft Messages which provide that without
    explicitly adding it as a parameter\.


- reply:  A flag\.  When set to `true`, the Actor receiving the message is
    expected to package up the return value of the method call into a
    Message and send it back\.

    Note that this is *a* mechanism, not *the* mechanism, for handling
    the result of a Message\.  I'll discuss more options below when we
    start to flesh out the coroutine loop for Maestro activities\.

    Just noting here that sometimes an Actor is in a position to hand
    off return values directly, and when that's the case, that's what we
    should do\.


- replyto:  I don't love this name, but `returnto` isn't great either, so it
    will do for a discussion\.  The default reply is back to the sender,
    but the payload might not be intended directly for the sender, but
    rather someone living on one of his slots\.


- ret:  An ntable containing the return values of a reply Message\.  This is
    what we call packaged return values in Valiant, and I see no reason to
    change that\.  I'd say that we want the array portion of a Message to
    be only used for method\-call parameters, because reusing it to return
    a payload in a reply would be confusing\.

The intention here is that `sender` is used to route the reply Message, and
`replyto` becomes `sendto` in the reply \(when present\)\.  That gets us one
level deep, and only covers the case where the reply Message goes back to the
Actor who sent the first Message\.

We can and should extend the protocol when we have more complex routing, but
we should also avoid this\!  Abstractions should pull their weight, and we
don't want the benefits we get from using an Actor\-Message architecture to
evaporate in weird bespoke control flow, with actions bouncing around some
complex addressing scheme which has to be stepped through to really understand\.

Unless we have no other choice, and at some point that might be the case\.

It's always tempting to keep going on this kind of design work, but at the
moment it's unclear when we'll even use some of these fields\.  It would make
sense for Maestro to include a request for a reply to a mouse click, but by
definition it doesn't know which Agent needs to handle it until Zoneherd
figures that out, and we don't really have to *tell* Zoneherd to reply, it's
smart enough to just do that\.

So let's take a look at the Maestro action loop\.  At some point the Message
specific parts of this document will get broken out into a distinct Message
project, for now, these topics are related in a "what happens next" sort of
way, more than anything\.


### Maestro, Modeselektor, Messages

  Maestro's job is to resolve input events into actions, then direct the
response to those actions\.  Most of these responses are the responsibility of
Agents, so Maestro is the boss of the Agents, and can message them directly
through ordinary method calls\.

Many of these actions require coordination between Agents, or require some
action be taken by a peer of Maestro, such as the Historian\.  We can limp
along in the short term with `borrowmethod`, but we need a robust architecture
here\.

Scattering borrowed methods or Windows all over the Agents is only slightly
better than just sharing a reference to `modeS` everywhere and calling down
the object chain\.  Worse, in one way: a user\-written library could at least
use `modeS` in that case, but if we didn't include a particular method or
enable Window access to a specific field, the user would have to either submit
a patch to helm or do without\.

So the general premise is that `modeS` calls `maestro` inside a coroutine\. Any
time an action requires something from e\.g\. the Historian, it can `yield` a
Message, with the understanding that modeS will `resume` any results
directly, since there's no reason to have to unwrap a return message every
time\.

Now, there's some unavoidable complexity here, and the only question is how
we choose to handle it\.  Namely, a lot of what the Agents need is from other
Agents, which means that Maestro could handle those himself\.

I see a few possibilities here\.  The easy case is when an Agent is done with a
method, and wants to `return` something which is used by another Agent\.  This
can be an ordinary `return` of a Message, it stays in the coroutine and
Maestro can dispatch it to the next Agent method as specified in the Message\.

But a major advantage of coroutines is that one can `yield` anywhere\.  There's
no reason to distort the logic of an operation by breaking it up into several
methods, just so that an Agent can phone the boss and get something back from
another Agent\.

So we have two choices there: either have an inner coroutine or let modeS
handle Messages which call through Maestro to one of the other Agents\.  The
latter strikes me as simpler\.

There is something mildly unsettling about being in a Maestro dispatch call,
yielding to Modeselektor, then reaching past Maestro to an Agent and resuming
right back into Maestro\.  But it isn't actually reentrant, Maestro is just
a dumb container for an operation like this\.

Except when it isn't\!  It's possible to yield a Message which directs Maestro
to do something himself, and that's actually fine\.  It could cause problems
if we're careless, but it probably won't: any recursion risks a stack overflow,
but that's a bad reason to eschew it\.

I don't like the alternative, because it means that every Message passes
through Maestro, even if it isn't intended for him or an Agent\.  So this has
to get relayed with another `yield`, the results handed back with two
`resume`s, and probably we need to do some `pack` and `unpack` in there as
well\.

So I don't think we want to treat Maestro as special\. It's just one of the
Actors living on `modeS`, which any given Agent or even sub\-instance in the
hierarchy might want to get something from\.

This leaves us with a very simple `repeat until` in `modeS`: we set up a
coroutine, and call it repeatedly, handling messages, until the coroutine is
dead\.

Now on the one hand, this is moderately opaque: Modeselektor is going to be
doing a bunch of stuff, and we have no idea what just looking at the code\.

But on the other hand, that's correct, because the task is completely
open\-ended, it's intended to be user\-extensible, and in that sense it's no
different from our old `modeS:act(...)` which works fine\.

Furthermore, this is actually much easier to inspect, because every message
will arrive in the same place in a legible form, which we could print to
status, trap in any fashion we want, and otherwise keep an eye on\.

The coroutine also traps any error thrown by actions, which gives us some hope
of recovering from that kind of thing\.  This is particularly nice for user
extensions, because it's frustrating to kill an entire program while working
on an extension for it\.  We can't guarantee that it isn't left in a bad state,
but we can at least keep trucking and hope for the best\.