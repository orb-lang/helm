# Dramatis Personae


  This is a guide to the actors which make up helm\.

It is written in the present tense, with an eye toward the future\.


## Background

  What follows is an attempt to make legible some of the most important
conventions of the bridge project\.

A perusal of the [style guide](httk://) for Lua would be a good prerequisite
to reading this document generally, and this section in particular\.


### Actors in Bridge

What does it mean to say an artifact of code is an actor?

We avoid the use of "object" in discussing bridge code\.  It has its place, but
is seldom the correct word to use to describe something\.  If a more precise
term applies, we use that instead\.

This is a table: `{}`\.  It is a map of anything, including itself, excluding
only `nil`, to anything else except `nil`\.  Or if you prefer, it's a map of
absolutely everything except `nil`, to `nil`, except where otherwise
specified\.

A table with a metatable, `setmetatable({}, Metatable)` is: a table with a
metatable\.  Metatables, and metamethods, are the [Meta Object Protocol](https://en.wikipedia.org/wiki/The_Art_of_the_Metaobject_Protocol) of
the Lua language, and they are magnificent\.

To expand a bit on objects: strings are very clearly objects\.
`(" "):rep(5) == "     "` makes this perfectly clear\.  Functions, being
first\-class closures, are also objects, we can introspect them and change
their state; coroutines as well\.

I see no reason to declare the other types to be "primitives", because Lua
semantics don't require it\.  The fact that we can't say `(2):times(print, is effectively an implementation detail\.  I'll grant you, it would
be
"hello")` pretty cool if we could\!  We can control the meaning of `2 + tab` with
metamethods, that's good enough\.

So sometimes it's quite sensible to refer to a table as an "object", when
we're considering it as a concrete artifact in the Lua runtime\.  But usually
we can be more specific\.


#### Of Modules and Instances

A common pattern for a module is to define a metatable, with associated
metamethods and such machinery\.  Such a module ends \(usually\) with a function
called `new`\.  `new` is assigned to a slot on the metatable,
`Metatable.idEst = new`, and the function is returned\.

This sort of module, when imported, is invariably done as follows:

```lua
local Widget = require "widget:widget"
```

That is, what was called `new` in the module `./orb/widget/widget.orb`, is
called `Widget` at the consumer side\.  `new` will take some number of
parameters, greater than or equal to zero, and return an *instance* of Widget\.
We avoid calling Widget a class\! It's already a module, and a metatable, and
a constructor of instances: that's a lot of things for one word to be, and
there's no *one thing* which has the Widget\-nature already, so why keep adding
nouns?

What this gets us is that the following generally holds true:

```lua
local Widget = require "widget:widget"

local thingum = Widget()

assert(thingum.idEst == Widget, "this property normally holds")
```

As an aside, this isn't flexible enough, and soon, before the year is out even,
we'll have to bite the bullet and rewrite it so that the call is
`thingum:idEst(Widget)`, where the simple case has `widget.orb` containing
`Widget.__type = new` after the constructor is defined\.

We describe any value accessed with a dot as a *field*, and if the value lives
on the table itself, rather than being returned through `__index`, it is also
a *slot*, so `instance.field`\.  Any valued accessed with a colon is a *method*,
and must be callable, so a function or a table with a `__call` metamethod: we
call this *passing a message*, so `instance:message(...)`\.

When a callable is or isn't a method is not objective, we can and do refer to
private functions which take the instance as the first parameter as methods,
and use the `methodCase`, generally with the `_privateModifier`, to define
them\.  After all, if we simply assigned them to a field on the metatable, they
would become a method, proper, and functions get moved onto and off of
metatables all the time, depending on whether it's useful to have them outside
the module\.

Bridge code never, ever uses `self`, we invariably define a method in the form
`function Widget.method(widget, ...)`, although the *section header* will say
`*** Widget:method(...)`\.


#### All the Bridge is a Stage

Is `thingum` then an actor?  Sometimes, but not often\.

What is and isn't an actor is necessarily somewhat subjective\.  It may be that
we can spell out hard criteria which an actor must fulfill to meet the
standard, but it isn't necessary, and will never be sufficient\.

We haven't talked much about actors, so this is all new information\.  It is my
hope that becoming explicit about this will help us write better software\.

The first thing is that an actor is *sui generis*, and unique\.  Some are
singletons, some are not: but there must be some distinctive aspect of the
actor which gives it personality\.

Second is that an actor **acts**, that is, it does things\.  It doesn't existonly\) to be acted upon, but to take action; and it doesn't exist primarily to
make
\( other objects \(see, not a useless word\!\), although many of them do
generate considerable objects and other data\.

Actors are generally long\-lived, but as we'll see here, that isn't always
true in `helm`\.  But maybe it should be\!  I think we'll find that we get more
out of actors if we clear their state and reuse them, rather than throwing
together a fresh one each time they have something to act upon, because this
will let us build up more complex relationships with their instance\.

So, to speak of [espalier](https://gitlab.com/special-circumstance/br/-/blob/trunk/doc/md/espalier.md), neither the Grammar nor the Node
modules are actors\. Both exist to create instances: Grammar makes grammars and
grammars parse strings into nodes\.  Are they factories?

\.\.\.I guess\! <throws up hands, makes face>

A given grammar is also not an actor\. Not really\. They are *sui generis*, but
they don't do, they are done with\.  PEG grammars are both Nodes and Grammars,
but again, they have a specific job to do and it isn't controlled by mutable
state\.

Nor is `br`, the artifact produced by [pylon](https://gitlab.com/special-circumstance/br/-/blob/trunk/doc/md/pylon.md), an actor\.  It's a
program\!  You can tell because it has a makefile\.  It has no metatable and is
created with no instance: it's just bridge\.

Orb, and helm, are clearly programs as well, apps even\.  In bridge parlance we
call them projects\.  A project has its own codex, and can be invoked with:

```lua
local proj = require "project"

-- or

local proj = require "project:project"
```

Projects which can be invoked from the command line with `br project` are
called **verbs**\.  Some are core to bridge, and we provide a mechanism to create
and install new ones, which are only slightly second\-class\.

I think this is enough of an introduction\.  Let's get to the meat of the
document: an introduction to the actors in bridge, and where we're going with
the design\.

As a reminder, this is a living design document: as it is written, it will be
speculating beyond what we have, and by the time that refactor is written, it
will have grown somewhat stale\.  I'll do what I can to keep it in tune with
what actually happens\.


## Dramatis Personae

Helm has more actors than any other program, by a large margin\.

In Orb, the Lume is certainly an actor\.  Skeins are probably actors as well,
in fact, let's go with that: despite being many, each has a personality,
defined ultimately by the File which provides the meat of each\.  They
certainly do things\!  Skein is written in a method\-chaining style, and exists
to successively mutate state\.  So a given run of Orb can have more actors than
helm, usually\.  It's just most of them are Skeins\.

Doc is not, though\. Doc is a grammar, there's no instance \(except of Grammar\),
and like any grammar it returns Nodes\.

\.\.\.actually Doc is a Node, but calling it invokes a Grammar\.  This actually
makes sense, bit confusing to just type it out though\.  It's just a convenient
way to do it, because the Doc format is a PEG grammar \(several in fact\) and
since PEG is a parsing format, parsing it returns a Node; PEG is defined theold fashioned" way, as a Lua function, because implementing the full
metacircular
" version is a bit of a hassle \(I did start the job though\)\.

So we attach a `__call` method to the start rule of PEG, and that calls a
generated Grammar which recognizes the universe of the defined grammar\.

But we're here to talk about helm\!  Without further ado, I introduce to you
the stars of the show\.


### Main Characters

These are the major arcana, which perfom the major tasks of helm\.

We begin with the protagonist, which holds nearly all state in helm\.


#### Modeselektor

The [Modeselektor](https://gitlab.com/special-circumstance/helm/-/blob/trunk/doc/md/helm/modeselektor.md), `modeS` by name, is our star DJ\.

All of `helm.orb` is one big function, with an environment, which sets up a
`uv` event loop, builds the modeselektor, and launches an event loop to run
it\.

Modeselektor holds the references to all other actors\.  We enter modeselektor
in response to *events*, which are currently all created by input\.  This is
handed to `modeS`, which does things with them\.

The Modeselektor has somewhat outgrown his name, but I think we're going to
stick with it\.  It comes from how we call him: we enter `modeS` when we get a
sequence of input, and `modeS` responds to that sequence by *selecting* the
response on the basis of the *mode* which helm is in at that exact instant\.

Which is mode in the ordinary sense of the exact state the whole system is in,
not "mode" in the vim sense or the emacs sense\.  What emacs calls a mode, we
call a raga\.

It turns out that to do that, `modeS` has to know all, see all, and do a lot\.
The role is one of coordination, and personally performing the big events\.

`modeS:act()` is the primary modeselektor method\.  In the `helm` loop, we call
`modeS(category, value)` and `ModeS.__call` is exactly this function:

```lua
function ModeS.__call(modeS, category, value)
   return modeS:act(category, value)
end
```

Which is deliberate\.  This lets us hook `:act`, replace it, and do anything
else we would care to\.  Though we haven't\.

Note that the new input parser changes the call signature, but not the basic
semantics\.

Modeselektor owns references to the other three main actors, and we're adding
a fourth\. They are the Historian, the Zoneherd, and Valiant, our evaluator\.

This is a distinct relationship\.  `modeS.hist` is, aspirationally, the **only**
reference to the Historian\.  Anything which owns such a reference can command
anything of the actor, and can delete it: and after that, the actor is
garbage\.

When an actor owns the only reference to another actor, we say that the owning
actor is the *Boss* of that actor\.  We can be as whimsical as we want in
describing the relationship in the other order\.

This is in fact one of the criteria for actors: no one can serve two masters
\(oops, looks like I'm cancelled\) and an actor should have **only** one reference
to it, owned by its boss\. If an Actor doesn't have a boss, well, then it's
the boss\.  `modeS` is an upvalue in `helm.orb`'s local namespace, when helm
returns, it goes out of scope, and show's over folks\!  Don't forget to tip
your waitress\.

We are in the process of introducing another big player, the Maestro\.  Let us
begin with what we have\!


#### Historian

  The [Historian](https://gitlab.com/special-circumstance/helm/-/blob/trunk/doc/md/helm/historian.orb.md) is in charge of the history of helm,
across all runs, sessions, and projects\.

Helm never forgets\.  Anything you enter into your helm is duly recorded and
kept forever\.  We don't even offer a mechanism to prune it, and we probably
won't\.  It's a SQLite database, if you want to do housekeeping you certainly
can\.

The Historian loads up a bunch of information from this database using
`helm-db`, a instance containing a proxy table\.  You pass it messages, it
returns prepared statements, and it has a few other tricks up its sleve\.

While a proxy table is definitely not an actor, it is an instance, but not one
which follows the usual objectesque pattern\.  Kind of its own thing\.

If we're running a Session, this also lives on Historian\. That's an actor as
well\.\.\. I think\.  It's kind of more a gets "done to" than a "doer", and I'm
making up the criteria as I go along\.  But let's say it is one for the sake of
argument\.  I would be uncomfortable with a second reference to the session
existing elsewhere, which is diagnostic\.

As we proceed, there will also be the Run, which makes a record of everything
from when helm is invoked to when it crashes or quits\.  You'll be able to tell
the difference: a run which quit will say "I quit" at the end, and if it
didn't, either it crashed \(we'll try to make a note but, you know\) or it's
still running somewhere\.

The Historian has even very recent history, such as the last line evaluated,
and it makes an effort to persist everything it knows just as soon as it can\.
Currently, this isn't true of the Session, but it really should be\.

Crashing should have as little impact as possible on the smooth functioning of
any bridge program\.

The most important data in the Historian, a cache of the last few thousand
lines, is stored in the array portion\.

Modeselektor holds what should be the only reference to the historian, at
`modeS.hist`, and invokes him frequently\.


#### Valiant

  [Valiant](https://gitlab.com/special-circumstance/br/-/blob/trunk/doc/md/session/valiant.md) is our old friend `eval`\.  He lives in his
own project, because we need him to run sessions from the command line as
well\.

Valiant is invoked by `modeS:eval()`, usually in response to the user hitting
the return key\.  Valiant evaluates the current text buffer, and returns any
results of the calculation, which Modeselektor dutifully hands to the
Historian for bookkeeping\.

D\.S\. note: I want to say that Valiant should be more directly exposed
to\.\.\.hell, I dunno who, but like, as much as possible it shouldn't be
\`modeS:eval\(\)\` but just talk to Valiant? But then how to handle the knock\-on
effects re: Historian, display of results, etc\. Maybe I'm wrong\.

This isn't a place to define everything an actor does, we have the modules for
that; this suffices as an introduction\.


#### Zoneherd

  The helm terminal screen is in raw mode, and broken up into panes which we
call Zones\.  Handling the layout of these is the job of the Zoneherd\.

The Zones are actors as well, their job is to paint Zones and communicate with
objects in the `.contents` slot, which are generally buffers, but can be a
simple string\.

Currently, Modeselektor has the only reference to the Zoneherd, on `.zones`,
but there is a lot of passing in the Modeselektor to other instances, to allow
direct calls, not even to the Zoneherd generally, but to specific Zones\.

We've proposed that, as a next step, both `modeS` and the Maestro will own
references to the Zoneherd\.  Which isn't exactly kosher, but if it were a
hard\-and\-fast rule, we'd want to enforce it with software\.  But it does
suggest that we want to have a better implementation before all of this is
done\.  It's better if we know that all calls on an actor will be either from
within its boss module, or at least preceded by the instance name of the boss
actor, that is, super\-boss calls boss calls the scrub\.

It is, in fact, an open question whether we'll have a Maestro at all\.  He's
taking over one of Modeselektor's most important jobs, and the easiest way to
implement the functionality is to just have promiscuous access to everything,
which only Modeselektor can be allowed to have\.

But I think we'll get a much better and more robust architecture out of the
deal\.

So let us continue, and explore the rest of helm's actors\.


### Yeomen

  There is no hard distinction between these actors and the ones we've just
sketched out\.

If anything, the distinction is that their role and implementation are
murkier\. The Historian, Valiant, and the Zoneherd all live on Modeselektor,
which holds the only reference to them, and is the only actor which should be
invoking them directly\.

In fact, the most important set of actors in this collection\.\.\. aren't actors
at all\!  But this is turning out to be a real barrier to a robust
implementation\.

I wasn't actually sure what I'd find when I started this section\.  But it
turns out that, unless I missed something \(distinct possibility\), there is one
actor, and one very broad class of not\-actors\-yet\.


#### Suggest

Suggest is our autocomplete module\.

It examines the context surrounding the cursor, and provides suggested
completions for a given variable or field\.  It needs to be narrowed a bit,
because right now it will continue to suggest completions from the global
context which it knows won't resolve to valid slots in a table\.  But it does
the job\.

It lives on the Modeselektor, and mostly acts by being passed the Modeselektor
and doing things to it: examining the Txtbuf, updating the suggest Zone,
telling the command zone it's been touched, etc\.

The fields aren't documented and really should be, but the state it holds is
essentially all possible suggestions, and the subset of suggestions which can
still apply given fuzzy narrowing\.  It also constructs highlighted completion
strings for the Txtbuf when the user is tabbing through possible completions\.

This is an expedient implementation, and there's nothing wrong with it given
where the codebase is at in general\.  But it isn't ideal\.  Just passing the
Modeselektor in means that it takes a close reading to know which parts of the
whole state Suggest needs to know about: the answer appears to be that it
reads and writes the Txtbuf, reads the raga name, and updates a couple of the
Zones\.

An easy win here is to pass in only the objects needed to perform these tasks
as parameters\.

I don't think actors like Suggest should be talking to Zones directly, since
the Zone is a hard\-coded presentation layer and we want to abstract that\.  But
we're still working on what that looks like\.


#### Namer

Right now the module repr:names is just that, a module, with no more specific
name being applicable\. This was fine when `valiant` was just a module, too,
but now that Valiant is a class and attempts to maintain a wholly
separate environment per\-instance, the names defined in that environment need
to be maintained separately as well\. Most likely this means making `names`
into a `Namer` class as well, and that `Namer` is probably an actor in
its own right\. Its boss is probably the `Valiant` instance that created it,
but `Suggest` also needs it\.\.\.another case of possibly\-dual ownership?


#### Rainbufs

  Rainbufs, as the [lede](https://gitlab.com/special-circumstance/~helm/-/blob/trunk/doc/md/buf/rainbuf.md) says, encapsulate data to be
written to the screen\.

The thing is, they aren't really actors\.

Are they *sui generis*?  Yes\.  Do they have personality, do they do things to
other things?  Yes and yes\.

But they're ephemeral\.  We instantiate a new one with every new contents\. If
we want to see that data again, we make a new Rainbuf\.  They're too
specialized, and not durable enough\.

They point to a missing actor, basically\.  But they're the closest thing we
have, so let's explore the implementation\.

Originally, Rainbufs were about printing the contents of tables\.  The naive
way of doing this is to render a string with the contents of the table, and
iterate it by lines, which is what the repl originally did\.

We didn't want to do that, because a large table can block the event loop,
which we avoid whenever it's possible given the single\-threaded nature of helm\.
Rainbufs can still handle a simple string, exactly by iterating it into lines,
but when given a result, they fire up a Composer and render only the lines
which the user has decided to look at\.

In the current implementation, which is a decided improvement, Rainbufs are a
class\.  We specialize them into Resbufs, Sessionbufs, and Txtbufs, for
results, session review, and text editing, respectively\.  We should also have
a `Selectbuf`, replacing the current usage of an object with a special
`__repr` \(`SelectionList`\) plus a `Resbuf` for suggestions and search results\.Funny thing, these 
are
\(
 actually "results" in the general sense, but, not
the same kind as the primary usage of `Resbuf`, namely REPL evaluation
results\.\)  We 
might
 need to specialize this into `Searchbuf` and
`Suggestbuf`, but I think it can be done with a couple config options a la
`Rainbuf.scrollable`\.

\(As an aside, this really points to the deficit in `idEst` being a field
instead of a method\.  Daniel did the same thing I've done with Nodes and
Phrases, putting a separate flag on Rainbufs called `is_rainbuf`; I used
`isPhrase` and `isNode`, which\.\.\. might be better?  The name of class\-like
modules is capitalized, but flags and inert things are generally in variable
case\.  Either way, it should be true of a Resbuf that `resbuf:idEst(Resbuf)`
and `resbuf:idEst(Rainbuf)` are both `true`\.  This is a meaty bullet but we
should bite it soon\.\)

This is going to be a problem for us going forward, because it conflates two
entirely separate things\.  Rainbufs are basically about markup and layout:
they have to know the allowable width, so that they can insert appropriate
line breaks, but they shouldn't know anything about the xterm protocol\.

And they certainly shouldn't know anything about how to edit text: and the
Txtbuf knows everything about how to edit text\.  The Txtbuf is the most "actor
like" thing we have which isn't an actor: it knows how to edit, it knows how
to lex, give printable content to Zones, but every time we change the command
buffer, we knock it on the head and make a fresh one\.

So ideally, a Rainbuf holds and returns ResLines, which are arrays of Tokens\.
It knows how to compose them, it can cache them, bust the cache and re\-render,
reflow automatically if given a different width, and so on\.  Because it knows
where every piece of text is within the abstract grid of the Zone, it can
process mouse commands \(and some other kinds of commands to be fleshed out
later\) to the underlying buffer; the ResLines will have "targets"
corresponding to certain regions of the ResLine, and will be smart enough to
directly return a value which will let the Rainbuf handle any changes to
layout implied by the mouse command, such as expanding or folding a table
print\.

And the Rainbuf we have *is a buffer*, so it has a good name\.  It needs to be
a buffer of ResLines, not, as the Txtbuf is, a buffer of both ResLines and the
actual text being edited\.  So the specialized\-class implementation is probably
sound, since a result should just be a result, it doesn't need to know about
Composers, it can be plain\-old\-data\.

We also want the backing state of a Txtbuf to be plain\-old\-data: it contains
all the editable content, the Codepoints in line\-arrays, cursor, anything else,
but is completely inert\.

These would not be actors, they do one job when asked, do it well, and become
garbage when they're done\.

But we need something which is, which I'm going to call an **Agent**\.  We would
have a ResultAgent, which would live on the Modeselektor \(probably on the
Maestro\) and have a durable existence\.

This application calls for synchronous communication, but we don't want shared
references\.  A mailbox isn't appropriate here: the Zone isn't the right place
for a ResultAgent to live, because we might not be sending it to a Zone at
all\.  Zones know all about xterm and have the ability to write to the terminal\.

And we can't have the ResultAgent owning a Resbuf, and a separate copy of the
Resbuf living inside the Zone, even though the Resbuf is smart enough to just
hand contents to the Zone to display it \(since a Zone will be able to render
ResLines into actual text\)\.

So what we want is a Window, exactly like in Composer, but this time we should
make a whole project for it \(and port Composer to use it\)\.  This lets the
Zone get anything it needs to from the ResultAgent\.  It can even be used to
mutate the Resbuf, in principle: but we should avoid this\.

And this gives us a much cleaner data flow\.  Valiant returns a result, which
Modeselektor gives to the ResultAgent\.  On `:paint`, the Zones consult their
windows: if something needs to be painted, it requests the relevant ResLines,
and does so\.

This makes painting completely optional: we could make `:paint` a no\-op, and
have a separate event on the loop which inspects the Agents and sends any
changes as JSON to a client, or `:paint` could cover some of the rendering and
an event could stream another buffer to a separate terminal process\.  We can
hook them to log something, or perform some other action \(screen readers?\)\.

Nothing should ever have to give content to the ZoneHerd or Zones, unless the
Modeselektor needs to replace an Agent\.  There's no need to touch anything,
because the Agents can tell the Zones when they need to paint\.  Modeselektor
will tell the Zoneherd when popups need to be replaced, and when reflow needs
to happen, and that's that\.


#### Txtbuf \-> EditAgent

As I mentioned, we really need to decomplect editing text from painting it\.

So the current Txtbuf should split off all edit functionality\.

For this, I think we do want an actor: a singular EditAgent, potentially more
than one, where the contents is replaced, instead of instantiating a new one
each time\.

So we have two things here, and they're both buffers, but we don't want to
call them both "bufs" because that's confusing\. But it's also ok, the "text
buffer" just exists as the replaceable contents of the EditAgent\.  When we do
things like up\-arrow, the Maestro tells the Modeselektor that Historian needs
to pull a new line and give it to the EditAgent, and the Zones just check this
on `:paint`\.

We want the contents in the form of a plain\-old\-data container, exactly like
results, with the Codepoint arrays, cursor information, and so on, so they can
potentially be passed from an EditAgent for the command Zone to an EditAgent
for a popup full screen editor\.

The EditAgent should own the contents, and the associated Txtbuf should have a
Window to retrieve the contents\.  This is completely transparent: it looks
like accessing slots on the same data structure, just that writing to it is
illegal, and when the contents owned by the EditAgent changes, the underlying
contents of the Window changes also\.  If the EditAgent disappears, then the
Window will fail an assertion and die with a meaningful error message\.


## The Maestro

  The document is pretty content\-rich, and there are a lot of changes built in
already\.

So I'm not going to try and go deep on the implementation of the Maestro\.  But
I am going to justify having one\.

Superficially, we don't need it\.  The Modeselektor can do the keymap resolving,
retrieve appropriate messages, and communicate with the Agents, the Historian,
activate the Zoneherd for painting, and so on\.

One thing which suggests we shouldn't: the Modeselektor module would become a
long piece of code, most of which does a complex dance around input, and then
has a shorter section which does a bunch of unrelated and very important
things\.  This is suggestive that there should be a Maestro\.

What I consider definitive, however, is that an input parsing uv event will
only be one way to activate the Modeselektor\.  Input events might arrive as
ØMQ packets, or JSON, and the Maestro can abstract this\.

Getting a good separation of concerns will probably involve mail\.  The most
important thing right now is to get Agents in place, so in terms of bringing
the new input parsing strategy online, the Maestro can just have God
privileges for awhile, which means that it can **borrow** modeS as a parameter\.

We can't have modeS as a slot on the Maestro, that's too much\.  But we should
think in terms of expedience for now, while we work out a strategy for the
Maestro to communicate with everything else, without violating the premises
that we've established here for Actor isolation\.
