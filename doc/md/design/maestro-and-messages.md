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
and reset it in a consistent, general way\.

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

In the particular case we're discussing, there's no need to specify that we
want a method on the Zoneherd, but this can be considered an elision\.
