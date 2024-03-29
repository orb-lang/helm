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

> DS: One **problem** this sort of architecture creates is that it separates
>     sending and processing of messages, meaning that when a message is
>     processed the send isn't on the call stack\. This sucks for debugging\. We
>     may be stuck with it, but I think this is a step **backwards** for reasoning\.

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
boundaries\.  Of the Lua objects, we can't stream functions, coroutines, or
\(in general\) userdata, but everything else is tractable and I don't envision
those just mentioned being common parameters\.

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


- message:  A Message which is dispatched to whatever is returned from
    dispatching **this** message\. In other words, `{ call = "foo",
    message = { method = "bar", "baz" } }` ultimately evaluates to
    `target.foo():bar("baz")`\.  These may be nested arbitrarily deep
    to produce a chain of calls\.


- call:  Value is either `true` or a symbol\.  If a symbol, call the function
    at that slot with the parameters, if `true`, then call the receiver
    with the parameters\.


- n:  Already mentioned, but for completeness, an integer >= 0 which specifies
    the number of parameters in the array portion of the Message\.

> DS: Why have `sendto` when we already need a mechanism to decide who even
>     gets a message in the first place? \(At its simplest this is just called
>     "knowing who's at the other end of a particular queue", and that may be
>     sufficient\.\) This is something of a rhetorical question\-\-I can see
>     situations where we'd use it, but it's usually going to be a Law of
>     Demeter violation, and frankly I'd tend towards leaving it out until we
>     actually need it\.

We'll need it immediately, when messages to modeS need to go to Historian\.

DS: Right, I was putting a lot on "a mechanism to decide who even gets a
message in the first place" without realizing that this basically **is** that
mechanism\. I do wonder how it interacts with Mailman, and especially my notion
of a MIMO Mailman with named "boxes"\. We certainly want to make sure that if
there's more than one way to send a message to someone, you identify them the
same way across the board\.

>
>     It also seems like there's a lot of redundancy between `method`,
>     `sendto`, `message` and `call`\. First off we could just use `method =
>     "__call"` for that case\. Strictly speaking this is ambiguous between a
>     function property in slot `__call` and a true metamethod, but \(a\) so
>     many of our metatables are self\-indexed that there is usually no
>     difference, and \(b\) if there is a difference and you care, Something Is
>     Wrong, please don't\. So I'd be fine with just special\-casing that if the
>     method name is "\_\_call" we just call the receiver\. Or not, this is
>     orthogonal to the other simplification I'm suggesting\.

A message is `target:message(...)`, a call is `target.call(...)` or if call is
`true`, it's `target(...)`\.

As you point out, conflating calling with a method via `__call` gets mixed up
with whether the metatable is a self\-table, so I'd rather have a mechanism
which works regardless of the minutiae of how we set up the instance\.

DS: Right, non\-method function calls\. Yeah, in that case we need both so might
as well also disambiguate `target:__call(...)` from `target(...)`\.

At that point though I would do:


- property: Just retrieve a property\. No parameters allowed in this case\.
    `{ property = "foo" }` \-> `target.foo`\.

- method: Call a method\. `{ method = "foo", "bar" }` \-> `target:foo("bar")`\.

- call: Call a function \(or the receiver itself if `call = true`\)\.
    `{ call = "foo", "bar" }` \-> `target.foo("bar")`

No `sendto`, handle that with a nested message like
`{ property = "foo", message = { method = "bar", n = 1, "baz" } }`\.

Alternatively, have `name` \(a symbol\) and `action` \(one of \{"property",
"call", "method"\)\. This is convenient for implementation \(we always need to
retrieve something, it's convenient to alsways store it under the same key\)
but yes, it is a little string\-ly typed\.

>
>     That being, replace `sendto` and `message` with something like
>     `callpath` or `sendpath`, which is an array\-table of keys to traverse in
>     order before calling the `method`\. So `{ method = "baz", path = { would ultimately result in
>
>     "foo", "bar" }}`     `receiver.foo.bar.baz(...)`\. But also, per my first paragraph, I would
>     tend to leave this out until we actually need it\-\-indeed until we need
>     it **more than once**, the first time I would just write a forwarder
>     function on the receiver itself\.

I considered and rejected that architecture\.

Each target in a call path needs the same flexibility as the receiver of the
message\.  The parsimonious way to handle that is to pass an entire Message in
the case where the primary receiver is forwarding the message to an Actor in
its call heirarchy\.

We're going to want to bake message dispatch into the class definition of an
Actor, they're all going to be able to receive them\.  So it will automatically
unwrap the envelope and dispatch the Message\.

DS: Right, need nesting to be able to handle the full range of possibilities\.
I updated the description of `message`, above\.

As an additional affordance, we could allow\.\.\.well, see above, I'm thinking we
don't actually need `sendto`, but we could allow it anyway **at construction
time**, and allow it to be a dotted path, and expand that into a nested message
like:

```lua
{ sendto = "foo.bar", method = "baz" }
-- becomes:
{ property = "foo", message = { property = "bar", message = { method = "baz" }}}
```

\-\-\-\-\-

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

> DS: \+1 this is good\.


- reply:  A flag\.  When set to `true`, the Actor receiving the message is
    expected to package up the return value of the method call into a
    Message and send it back\.

    Note that this is *a* mechanism, not *the* mechanism, for handling
    the result of a Message\.  I'll discuss more options below when we
    start to flesh out the coroutine loop for Maestro activities\.

    Just noting here that sometimes an Actor is in a position to hand
    off return values directly, and when that's the case, that's what we
    should do\.

> DS: How would this be the case?

@atman:
        Actor dispatch will always `return` the value of the dispatch: if
        there's a `reply` flag, it packages those return values into a Message\.

When there isn't, as in the coro loop, we have additional logic which handles
the return values: in this case, we call the dispatch inside `resume`, so
no need to `pack` and `unpack` the result\.

DS: Right, I asked this and then later got clear about the
synchronous/asynchronous distinction\. I'm still not really getting the
purpose/need for `reply` and `replyto`, honestly\. Like, asynchronous messages,
in my experience, generally don't have "replies"\. They may prompt the person
receiving them to need to talk to someone, and that someone might happen to be
the sender of the original message, thus making it a sort of "reply", but it
still happens on the initiative of the receiver, rather than by request from
the original sender\.

Also\. This interacts with the whole thing of do we have a global Mailman with
named boxes, or route everything through modeS, or what? Like, it's not
automatically clear where to **start** when sending a reply\-\-not the receiver,
but the receiver could itself be many levels deep, and we discussed how the
nesting thing is useful in that it **hides** that from the ultimate receiver, a
message looks the same no matter what path it took to get there\.


- replyto:  I don't love this name, but `returnto` isn't great either, so it
    will do for a discussion\.  The default reply is back to the sender,
    but the payload might not be intended directly for the sender, but
    rather someone living on one of his slots\.

> DS: I would YAGNI this for now, and implement it as `replypath` analogous with
   `sendpath` if/when we need it\.

@atman:


- ret:  An ntable containing the return values of a reply Message\.  This is
    what we call packaged return values in Valiant, and I see no reason to
    change that\.  I'd say that we want the array portion of a Message to
    be only used for method\-call parameters, because reusing it to return
    a payload in a reply would be confusing\.

The intention here is that `sender` is used to route the reply Message, and
`replyto` becomes `sendto` in the reply \(when present\)\.  That gets us one
level deep, and only covers the case where the reply Message goes back to the
Actor who sent the first Message\.

> DS: So a function call and return is fundamentally asymmetric\. The caller
>     needs to know who they're talking to and get everything in order, the
>     callee just offers the return value up to the world without knowing who
>     it's going to\. With an asynchronous messaging system, fundamentally
>     every message has to know its receiver, which means in order to reply,
>     you need to know the sender of a message\. This is great so far\.
>
>     But at that point, what makes a reply different from any other message?
>     Seems like\.\.\.nothing, really? And when the reply gets back to its
>     sender, how does the sender know what to do with it? We could route all
>     "replies" through a single `_dispatchReply` function or something, but
>     that seems inferior to just\.\.\.receiving new messages that happen to be
>     related to one that was sent earlier\. In which case there's no need for
>     `ret`, it's just another message\.
>
>     So\. I would suggest, for now, that we start with `sender` \(and the
>     implementation on Agent that you suggested to handle it automatically\),
>     and any message that needs a reply, well, the receiver just sends an
>     appropriate message back\. If we start seeing a lot of uses of this
>     pattern, and if for instance different senders of the same message want
>     different replies, then I would suggest making `reply` a sort of
>     "message prototype", a Message with everything filled in except the
>     sender, receiver, and arguments, which the reply\-er will finish filling
>     in and send back\. That takes care of all the nuances of where it goes
>     without adding any new fields\.
>
>     All that said, also see below about how this interacts with the
>     coroutine loop, which suddenly **isn't** asynchronous\.

@atman:


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

> DS: Right\. So here's the thing\. We have some messages that we send
>     asynchronously, by putting them on a Deque somewhere probably\. There
>     might be a logical "reply" to these, but if so, IMO it should just come
>     as another message directed back at us, with no special affordance for
>     "being a reply"\. Likely we won't even need the ability to specify **that**
>     there should be a reply, or where it should go, because this will be
>     obvious, though we can add those if needed\.

A method shouldn't need to know that it should package a reply in a Message,
and as I indicated above, there are cases where the return values
don't **need** to be a Message and that just creates extra work\.

DS: See my latest notes about `reply` and `replyto` above\-\-but we can swing
back around to this, no need to decide right now\.

So yes, we *can* handle these cases with custom logic, and probably *should*
for the immediate applications we're putting Messages to\.

But we can't do so in a general way without additional information\.

>
>     Then we have messages `yield`ed to `modeS`, which are actually
>     **synchronous**, and as such, sure, they can have return values, but
>     that's because they behave **exactly like function calls**, just with more
>     indirection\. The receiver doesn't need to know anything about where the
>     return value is going, and the return value isn't a `Message` at all, it
>     will become the return value of the `yield`\.
>
>     It's good and correct to have a unified reification of a `Message`, and
>     to use that for both queued and `yield`ed messages, but I don't actually
>     think we need **any** of the reply\-related machinery \(except `sender`, but
>     that mostly because why the hell not and it might be helpful for
>     debugging\)\. Synchronous messages just\.\.\.can have return values\.\.\.while
>     async messages rely on the receiver to respond if needed \(for now, and
>     we can do something later if we need it\)\.

@atman:
        "things we're obviously going to need" and "things we might not need
        which are natural extensions of the basic protocol"\.


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

> DS: \(Re: starting from "I see a few possibilities here"\.\) "Next"? I'm thinking
>     about this in context: We start with an input event, `modeS` spins up a
>     coroutine in which `Maestro` translates that into\.\.\.what is logically a
>     `Message` but in fact is just **him calling a method on an Agent**\. This is
>     synchronous\. If the Agent needs to talk to another Actor \(Agent or
>     otherwise\), it `yield`s a `Message`, which `modeS` processes and `resume`s
>     the coroutine with the return values\. From the Agent's perspective this is
>     also synchronous, so there's no situation where we'd be breaking up an
>     operation in order to phone the boss\-\-we phone the boss, the boss **picks up**
>     and \(synchronously\) answers our question and life goes on\.
>
>     Aside: We could also do this by allowing Agents to have a backlink to
>     Maestro, and just call it and each other as normal function calls\. This seems
>     like it's not that different from indirecting through modeS, in that Maestro
>     is never going to be in another process from the Agents or anything like
>     that\-\-right? \(Neither is modeS, really, but some of the other Actors might
>     be, like if we're running Python code instead of Lua, `eval` might be\.\) If
>     there's a reason this seems bad, I'd like to hear it, it might help clarify
>     how you want the whole thing to work\.

Two things\.  First, that's not a safe assumption\.  An example would be a
language server, and we'll be adding that sort of thing relatively soon\.

Second, we'd be reconstructing the sort of objects\-call\-objects architecture
which we're moving away from, just in a subset of the program\.  As we've
discovered, teasing that sort of thing apart gets expensive\.

It leaves us with two mechanisms to get outside of an Agent's primary
responsibility, instead of one\.  We need to pay the cost of doing all this
dispatch already, so I'm confident we'll want to lean in and use it
consistently, this lets us rely on it in various ways\.


>
>     Now, potentially more than one Agent is interested in the input
>     event\-\-potentially there is more than one matching entry in a keymap\. \(We
>     haven't talked about this and may not be on the same page, so if this seems
>     wrong let's straighten that out first\.\) But in that case, IMO there should be
>     no actual communication between successive consumers of the same input\.
>     An Agent should be able to say "the buck stops here, nobody else gets to
>     process this", like `evt.stopPropagation()` in JavaScript\-\-or possibly
>     something more nuanced\-\-but not affect what method is called or its
>     parameters for the next guy in line\. The whole dispatch mechanism is
>     basically an outer loop here\.
>
>     When aaaaalll is finally said and done, `Maestro` returns and the coroutine
>     dies\-\-but it dies without returning any values, because at this point it's
>     too late, if Maestro/the Agent wanted something that needed to be done with
>     a `yield` earlier so there'd be somewhere to `resume` the return value\. I
>     suppose it could return a "just one more thing" message which modeS would
>     process and throw away the return value, that's really neither here nor
>     there\.

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

> DS: Yep, this sounds fine\.

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
