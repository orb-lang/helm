# Helm With Cluster and Actors


  A design document for helm's immediate future, as of @git://20e9721e5df1 \.


### Recent Changes to helm

  Modeselektor and Maestro \(only\) are full\-fledged Actors, extending from the
[Actor base](https://gitlab.com/special-circumstance/br/-/blob/trunk/doc/md/actor/actor.md) using [cluster](https://gitlab.com/special-circumstance/br/-/blob/trunk/doc/md/cluster.md)\.

There exists an excess of modules named cluster in various bridge repos, and
we will winnow this down to only the codex named cluster in short order\.

As promised, the process of launching an Actor within a coroutine which
receives and dispatches the [Message](https://gitlab.com/special-circumstance/br/-/blob/trunk/doc/md/actor/message.md) protocol has been
put in the base layer where it belongs, and is invoked by calling `:task()`
before an ordinary method call, or by calling the Actor itself, which uses
the default method `:dispatch`\.

The way these connect behind the scenes isn't inordinately complex, and I
intend it such that reading Actor and then either of Maestro or Modeselektor
should make sense, with the pieces of cluster explained in\-line rather thanor rather, differently from\) how they are introduced in cluster itself\.

\(
I've been making headway with Orb, with the specific intention to add enough
keywords and compilers to allow inlining of plantUML and dot, along with
re\-formalizing my now scattered refs collection so that links work\.

The intention is that I can get one more squeeze out of the Markdown renderer
by talking it into inlining SVGs from the `/etc` directory\.

To continue with helm, I've made it so that any `send` from an Agent is
invoked through an Agent base method `:send`\.

It's clear that `I :send {msg}` is going to be one of the universal Actor
interfaces, since they should understand, in detail, how to communicate with
other Actors *actively* rather than *responsively*\.  `:send` and `:dispatch`
are dual, although we apply Postel's law to `:dispatch` andaspirationally\!\) don't crash on any sort of input, because `:dispatch` is a
`yield`
\( boundary and anything can end up on it\.

The other changes are modest, what comes to mind is that I was experiencing
event loop exhaustion with the one\-idler\-per\-result architecture in Historian,
which I replaced with idle\-until\-queue\-empty\.

We're going to be adding more queues, but not immediately\.

The current architecture can experience race conditions fairly easily, and
the solution is for tasking to enqueue and then execute or return\.


### Next

The task at hand is to ensure that certain invariants are being met throughout
helm\.


- Invariants:

  -  Actors \(to include Agents\) have only one strong reference\.

  -  The resolution of an input event produces a string\. It is the Maestro's
      job to combine the input event and the returned string and orchestrate
      the responses to it\.

  -  Keymaps are composed at\-most\-once\. This one is related, and returning
      **only** strings makes this simpler\.

  -  All Agents to perform work on a table at a field called `.subject`\.  The
      Agent may have mutable state of its own, but this is never to be
      conflated with the subject, and to be an Agent is to have a `.subject`,
      which is a plain table\.  Metatables aren't per se forbidden, more on
      that later, I want to emphasize that we have no Subject base and I don't
      see a need for one on the horizon\.  Rifle is fine\.


## Keymaps, Ragas, and "mode"

We need clarity here, so I'll summarize the intended architecture rather than
basing on what we have now\.

We use the term Raga for a specific implementation detail of helm which is not
visible to the naive user\.  The word "mode" is semantically rich in text
editing, and we present a user interface which meets that expectation\.

The Raga itself is effectively \(and perhaps should be, I'm leaning toward it\)
the subject of Maestro\. It carries all the state needed to perform the
expected response to the next input event\.

We really have one mode right now, and it's Nerf, although Page does follow
pager conventions rather than readline\-esque ones\.

The number of ragas we're carrying right now is about right, and we need to
build these out of keymaps and handlers\.  Which are duals, like `:send` and
`:dispatch`\.

Everything living in the raga directory needs to migrate in two directions:
mapping from input events to strings, and handlers, which an agent calls
like this `agent:handle(string, event)`\.

This is a yieldable and eventually returns a reply when the Agent has no
further action to take on the Task \(which Maestro creates\)\.


### Keymaps

The sentence "user can completely rearrange the keymap with an appropriate
manifest file" is a goal, but not the immediate one\.

It's the interface which we have to harden, and that is a string, which we're
going to call an action\.  The keymap is `fn(inputEvent) -> action`, so
`'none'` for no action, not `nil`\.

We will *extend* rather than change this, when we have to, by adding packed
parameters\.  These will be as literal as practical, and intended to support
translation of e\.g\. `d4j` into something more like `'delete-down', {4}` than
`delete-down-4`\.  The latter implies a sort of stringly typed runtime
construction which I would prefer to avoid, `'-4'` being less homoiconic than
`{4}` for reading Lua tables as pure data\.

The keymap itself is not expected to be declarative, we can use whatever
functions we need to get the appropriate behavior, but it can't, like,
borrow Modeselektor anymore\.

Since readline is stateless, this is simple in the whole and tricky on the
margin\. If we can just say what a key press does, great, make that into a
string\.


### Ragas: helm:maestro/ragas


Ragas are a runtime construct, state machines containing, at least, keymaps,
the 'target' Agent, action handlers, and necessary bookkeeping methods, like
`:onPush`, `:onShadow`, and `:onShow`\.

The keymaps associated with a raga should go in a new `keymaps` folder where
we whittle them down relentlessly to a declarative form, and all the
associated ragas are constructed in one raga module, for now\.


#### Maestro raag\-shift algorithm

This should be good enough and offers ways to elaborate\.

We build something I'll call a directed stack\.  It has two operations, `:push`
and `:pop`, and the stack take care of removing any cycles, and never pops
empty, we'll have a method to replace the base of the stack but it won't be by
ever underflowing the stack\.  We'll call the base of the stack the `base`, it
is `nerf` for our normal mode\.

So if we push the sequence `premise-edit, title-edit` twice, the stack is
`[base, premise-edit, title-edit]`\.  There is a canonical way to un\-cycle when
we need that behavior, but for what we have now, we won't need to do
excursions, just cycle elimination\.

A Raga gets `:onPush` when it's pushed, `:onShadow` when something goes
over it, and `:onShow` when a shadow is popped off of it\.



