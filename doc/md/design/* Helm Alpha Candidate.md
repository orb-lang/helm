# Helm Alpha Candidate


  Helm is finally at a point where we can enumerate what's needed for a
release candidate\.

This is going to be a brain dump of features and architectural changes, which
we can eventually harden into a collection of issues in this or another
document\.


## Architecture

  Helm as of \!156 is as awkward as it should ever be\.

We began with a system build on objects calling each other directly, via
promiscuously shared references\.  In an earlier stage we did a good job of
encapsulating functionality into well\-defined objects, and established a
data\-flow paradigm which at least flowed toward the screen\.

\!156 has gotten us right up to the halfway mark, with an initial
implementation of a change which will become the core algorithm of helm:
using coroutines and the event loop pervasively and cooperatively to build a
reactive framework based on message passing and responsive input event
handling\.

Each change from this point should make the underlying architecture easier to
reason about, more uniform and robust\.


### Modeselektor

  Asymmetric coroutines are a powerful abstraction precisely because they
allow for an imperative style of programming with \(cooperative\) multitasking\.

Callback\-driven event loops cooperate with this style exceptionally well, for
a few reasons\.  One is that the red/blue function distinction *can* and
*should* be pushed to the edges, leaving "purple" functions which do the
right thing depending on context\.  A second and related reason is that this
flattens the callback pyramid, where structures like promises and async/awaid
merely elide it\.  The coroutine, by `yield`ing and `resuming` across callback
boundaries, simply continues once all middle layers have had their say\.

To get this effect we're going to have to pay for it up front\.  Coroutines
compose, but they do so manually\.


#### The Main Event

  Our current architecture runs everything responsively from inside the input
event handler, which is itself not a coroutine\.  It's been modified to *run*
a coroutine and process that coroutine effectively as a message\-dispatch
iterator, and I've had some difficulty expressing how that needs to change
beyond high\-level invocations of inversion of control and so on\.

I have a detailed architecture now, and I'll describe it, then try to back
that up with some diagrams at some point\.

When Modeselektor receives an input event, it needs to do this: create a fresh
coroutine, set up a check \(specifically check, which is after I/O\) event,
which just resumes the coroutine\.

Last, or rather before exiting, it sets up another check event\.  This one just
checks the status of the main event coroutine; if it's dead, it shuts
everything down, the end, otherwise it keeps running every event tick\.

So what happens inside this coroutine? Everything which flows from the input
event, whenever it can\.  The loop catches the yield values, and when those are
Messages it dispatches them\.  Currently, our yield/resume pattern for callback
async yields `nil`, and we can profitably improve on that, but carefully, and
it's a reasonable semantic for what we can do with it right now\.

Which is just to yield and wait\.  I keep mentioning that \(asymmetric\)
coroutines are a composable abstraction, and this is part of why\.

Let's say an Agent calls out to the filesystem, which causes a yield to await
I/O\.  The Maestro sees that yield, and it doesn't have any data, so Maestro
yields his own coroutine with no data, that bubbles up to the Modeselektor
coroutine, which is then also yielded, bringing us back to the event loop\.

Which `resumes` the coroutine running when the filesystem returns with data,
and placing the entire stack right back where it belongs\.  Yielding out of
several levels of nested coroutines and then getting right back into them with
one `resume` is a big part of the power of coroutines\.


#### Better coroutine protocols

  You'll notice some hesitation in the nil\-punning which I'm proposing above\.
That's real\.  The immediate issue is that the process spawner and
File/Directory code all yield nothing when leaping across callback boundaries,
and I'll need to make sure that consuming code isn't relying on this behavior
before I'm in a position to improve it\.

It should be okay to yield something more meaningful\.  It's great to push the
intelligence out to the edges, but communicating with the centre about those
decisions can only help us really\.

A good choice would be to yield the pair `(co, handle?)`\.  If we use this
consistently, we can get a lot out of it, because our existing coroutines
yield either nothing or entities which aren't of type `thread`\.

If it's just the thread, that says "resume me whenever and I'll continue",
while with the handle it says "this thread is expected to pick up inside this
handle", which gives a supervisor a chance to check in and see that this
process is healthy\.

Sometimes the decision to defer to another event should be left to the author
of the coroutine, which is what you get with returning the coroutine itself\.

Any situation where the coroutine needs to be resumed with specific data is
not a use case we can generalize, but we can specialize it, as we have with
Messages\.  Having this kind of consistent behavior as a backstop to
`dispatchmessage` would make sense, because this control flow pattern is all
about allowing Actors to work correctly without implementing all of Erlang\.


#### Maestro

This architecture will have far\-reaching consequences for Maestro\.

Maestro will also set up an inner coroutine per input event, but here there's
no need for a separate event\.  What we do need, everywhere, is reentrancy, and
Maestro is where that will be particularly acute\.

Fortunately for ease of implementation, this bug manifests as a race condition,
and given that our architecture is largely blocking in practice, we aren't
going to grind against it very often before we have the leisure of fixing it\.

It's a critical point however, because the inevitable response to this
situation is to queue everything an Actor does and then ask it to do something
if it can\.  If the answer is no, yield and ask again until the answer is yes\.

The key to making this work is that it's generic behavior common to Agents,
probably using a protocol which is either Actor\-generic or at least not
Agent\-specific\.  Probably the former, it isn't much of an Actor without a
working memory, and an inbox queue is a standard pattern which is there for a
reason\.

So it isn't an explosion of instances of "queue this, ask, yield, resume, knit
one purl two", all of that just looks like a message pass if it's upstream or
a method call / coroutine resume if it's downstream\.

This also makes queueing messages to the Zoneherd not\-special in a way we want\.
More about Zoneherd later\.


#### The target

  This is an important concept/category which will move us a long way toward
the declarative style\.  The Maestro will always have a target, and act in terms
of the target\.  This is canonically the EditAgent, although Pagers and Modals
are just as likely, but in any case, there is always a primary Agent which gets
first crack at responding to the action\-string resolved from the keypress\.

There's a whole exegesis about **mouse** events but let's not drown in detail
just yet\.


#### Modal Stack With Cycle Elision

The most important thing Maestro actually does is switch ragas, which are a
composed map of the full state Maestro needs to track, such as the target,
the keymap, and so on\.

Each of these is a table with a name, which Maestro can just swap onto the
register and use\.

What we need is the ability to just push new ragas onto this stack, such that
we can go back anytime we want, but don't have to think about going forward\.

Since the ragas are concrete state, this is simple: we push the latest state
onto the top of the stack, and the stack is traversed to remove any cycles\.

This will simplify implementation of vril, as well as interactions like moving
between a Session and editing various premises \(let alone re\-running and so on\),
which can choose between escaping to the previous context and just going forward,
depending on which makes more sense\.

This will happen alongside of isolating the effect flow and expressing it in
terms of actions and handlers, insofar as possible, after the triggering of
the initial call\.


### Zoneherd

, the obvious point being that it should paint on an
event, with the consequence that opportunities to paint are interleaved with
everything else\.