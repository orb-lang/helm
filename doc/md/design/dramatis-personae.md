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

We eshew the use of "object" in discussing bridge code\.  It has its place, but
is seldom the correct word to use to describe something\.

This is a table: `{}`\.  It is a map of anything, including itself, excluding
only `nil`, to anything else except `nil`\.

A table with a metatable, `setmetatable({}, Metatable)` is: a table with a
metatable\.  Metatables, and metamethods, are the [Meta Object Protocol](https://en.wikipedia.org/wiki/The_Art_of_the_Metaobject_Protocol) of
the Lua language, and they are magnificent\.

#### Of Modules and Instances

A common pattern for a module is to define a metatable, with associated
metamethods and such machinery\.  Such a module ends \(usually\) with a function
called `new`\.  `new` is assigned to a slot on the metatable,
==Metatable\.idEst ` new`, and the function is returned\.

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
`Widget.__type = new` after the constructor is defined


#### All the Bridge is a Stage

Is `thingum` then an actor?  Sometimes, but not often\.

What is an isn't an actor is necessarily somewhat objective\.  It may be that
we can spell out hard criteria which an actor must fulfill to meet the
standard, but it isn't necessary, and will never be sufficient\.

We haven't talked much about actors, so this is all new information\.  It is my
hope that becoming explicit about this will help us write better software\.

The first thing is that an actor is *sui generis*, and almost always unique\.
We might construct a mock actor for tests, but as a general rule there is
going to be on instance of each actor module\.

I can imagine this admitting of exceptions, but in `helm`, there are not\.

Second is that an actor **acts**, that is, it does things\.  It doesn't exist to
be acted upon, but to take action; and it doesn't exist primarily to make
other objects \(see, not a useless word\!\), although many of them do generate
considerable objects and other data\.

So, to speak of [espalier](@br:espalier), neither the Grammar nor the Node
modules are actors\. Both exist to create instances: Grammar makes grammars and
grammars parse strings into nodes\.  Are they factories?

\.\.\.I guess\! <throws up hands, makes face>

A given grammar is also not an actor\. Not really\. They are *sui generis*, but
they don't do, they are done with\.

Nor is `br`, the artifact produced by [pylon](@br:pylon), an actor\.  It's a
program\!  You can tell because it has a makefile\.  It has no metatable and is
created with no instance: it's just bridge\.

Orb, and helm, are clearly programs as well, apps even\.  In bridge parlance we
call them projects\.  A project has its own codex, and can be invoked with

```lua
local proj = require "project"

-- or

local proj = require "project:project"
```

I think this is enough of an introduction\.  Let's get to the meat of the
document: an introduction to the actors in bridge, and where we're going with
the design\.

As a reminder, this is a living design document: as it is written, it's going
beyond what we have, and by the time it's written, it will have grown somewhat
stale\.  I'll do what I can to keep it in tune with what actually happens\.


## Dramatis Personae

Helm has more actors than any other program, by a large margin\.

In Orb, the Lume is certainly an actor\.  Skeins are probably actors as well,
in fact, let's go with that: despite being many, each has a personality,
defined ultimately by the File which provides the meat of each\.  They
certainly do things\!

Doc is not, though\. Doc is a grammar, there's no instance \(except of Grammar\),
and like any grammar it returns Nodes\.

But we're here to talk about helm\!  Without further ado, I introduce to you
the star of the show\.


### Modeselektor

The [Modeselektor](@:helm/modeselektor), `modeS` by name, is our star DJ\.

All of `helm.orb` is one big function, with an environment, which sets up a
`uv` event loop, builds the modeselektor, and launches an event loop to run
it\.

Modeselektor holds the references to all other actors\.  We enter modeselector
in responsed to *events*, which are currently all created by input\.  This is
handed to `modeS`, which does things with them\.

The Modeselektor has somewhat outgrown his name, but I think we're going to
stick with it\.  It comes from how we call him: we enter `modeS` when we get a
sequence of input, and `modeS` responds to that sequence by *selecting* the
response on the basis of the *mode* which helm is in at that exact instant\.

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

Modeselektor owns references to three other actors, and we're adding a fourth\.
They are the Historian, the Zoneherd, and Valiant, our evaluator\.

We are in the process of introducing another big player, the Maestro\.  Let us
begin with what we have\!
