# Refactoring Ragas


  Time to tackle ragas\.

We've made a lot of progress on reducing global state in `helm`, decoupling
components, and delineating areas of responsiblity within the system\.

Ragas, the part of helm which responds to keystrokes, are lagging in that
respect\.  This is typical of a bootstrap, but it's time to refactor them\.


### Keystroke parser

This first issue is fortunately self\-contained: we shotgun keystrokes into
various categories\.  This isn't *badly* done, I'd say that the categories we
use \(ASCII, UTF8, ALT, CTRL, PASTE, NAV, and MOUSE\) are reasonable, although
NAV is kind of unprincipled, a grab\-bag of terminal sequences which are issued
by arrow keys, PgUp/Dn, and so on\.

The biggest problem here is that, if anything hangs the event loop for long
enough for the buffer to fill up, our shotgun parser just drops things on the
floor\.

So this is one, reasonably self\-contained task:


#### \[x\] Write a better terminal sequence parser

I think we should be using `lpeg` for this, but using it directly: The output
is a sequence of \(category, value\) tuples, not an abstract syntax tree, so the
existing PEG machinery is going to fight against us\.

In any case, this needs to break the assumption that exactly one sequence is
arriving at a time, so it should produce a pair of \(\(category, value\), index\),
such that if `index < #seq`, we send the tuple off to `modeS` and keep parsing
from `index` until the sequence is consumed\.

##### \[ \] Optional: distinguish numeric keypad from number row

There is a thing called "application keypad mode" that causes the numeric
keypad to send escape sequences of the form `SS3 [j-yX]`, i\.e\. `ESC O [j-y]`\.
\(This is distinguishable from an alt sequence because Alt\-Shift\-o is encoded
using `CSI u` as `CSI 79;3u`\.\)\.


### \[ \] Conflating keystrokes with actions

  This is one of the places where we're rapidly painting ourselves into a
corner\.

It's impossible to discuss this without some leakage from later parts of this
document, I'll do my best to keep that to a minimum\.

Currently, we have exactly one raga, and stateless shifts to new ragas which
constitute a state machine, one which is somewhat scattered between modules\.

All of those things are problems, but not the one I'm addressing here, which
is that ragas act on \(category, value\) pairs directly\.

What we need is a two\-stage process, where keystrokes are turned into
something with more semantic meaning by the parser, and this is then resolved
into a message, which is sent to the raga\.

There are more layers than this, but that's the essence of it\. The raga itself
is a layered stack of available functions, with some kind of 'action resolver'
sitting on top of it, translating user commands into those actions\.

I'm not entirely sure what to call the latter, but I'm going to go with
"keymap" until/unless I come up with something better\.

This is important because interaction at a terminal is only one contemplated
mode of helm interaction\.  We need to be able to run it headlessly, and should
be able to front it with a GUI, a web client, and anything else that comes up\.

It's also important for user extensibility: it gives all the functions of the
ragas as direct actions, and allows us to provide the ability to hook events\.


### \[ \] Layered keymaps and ragas

  Our current ragas are flat: we use cloning to borrow commands out of other
ragas \(at this moment, only the EditBase pseudo\-raga\), and lookup proceeds
accordingly\.

We need them to be in layers, and the same for the keymaps\.  This isn't
immediately urgent, but it's critical for helm's future: we intend it as a
general\-purpose interactive environment for exercising and *editing* Orb
documents, which means that running the REPL inside the same Lua state as helm
itself will be quite impossible, since the code might well be Python or
conceivably anything else\.

We can't achieve this layered effect by simply setting base ragas to be the
metatable of overlay ragas, because that mutates the overlay, and introduces
state, precisely what we wish to avoid\.

But we do want it to behave that way: lookup on a keymap should simply be
`message = keymap[category][value]`, and dispatch should be
`raga[message](...)`\.  Maybe not those exact signatures, but something to that
effect\.

So we need keymap and raga **resolvers** which look through these layers and
come up with appropriate messages\. Tentative name for this/these: "maestro"\.

At least the keymap resolvers, and possibly the raga resolvers as well, need
to be able to hold state\.  We'll have a keymap resolved for the vril\-normal
raga, as one example: it needs to be able to take the sequence `d, 3, w` and
store it until it can send the message `{'delete-word', 3}` or something of
that nature\.

The keymaps and ragas themselves must be completely stateless; we should think
of them as immutable, although it may not be worth the extra steps to actually
make them so\.

A raga is mostly a collection of keymaps \(definitely more than one to aid
composition\)\. May also be where the functions referred to by those keymaps
live?


#### Problems we need to solve


##### Composition of functionality

Right now we have Nerf, which is really made up of lots of distinct bits of
functionality:

-  Basic text editing

-  Syntax highlighting and brace matching

-  Suggestions

-  History navigation

-  Evaluation

-  Results display, scrolling etc\. \(and eventually all sorts of fun stuff like
    mouse interactivity\)

When considering a suggestion \(having pressed tab\), or in search mode, we need:

-  Scrolling through the list of suggestions/search results

-  Ghost display of the suggestion/search result
But note that the list lives in different zones in these two cases\.

We also need what amounts to a modal editor/prompter, a way to edit a piece of
text and then accept/save and return to what we were previously doing\. The
only case right now is editing the title of a session premise, but in any such
case, we'll need:

-  A concept of 
what
    we're editing, so we can store the result back there
    when we quit

-  Change detection and prompt to save changes if we try to go do something
    else when there are changes\.

So clearly we need a way to break out some of these bits of functionality, both
from each other and from being tied to a specific Zone, so we can recompose them
to use for other purposes\. Allowing a raga to activate multiple keymaps is a
part of this, but I think there are unanswered questions about where the
**implementation** of the functions should live, and how the whole focus thing
works\.


##### Complex commands and input buffering

`emacs` has shortcuts like `C-x C-c`, Ctrl\-X followed by Ctrl\-C\. `vim` \(and
thus `vril`\) has commands like `d3w` as mentioned above\. The `C-x C-c` case we
can handle the way emacs does: have the value for `C-x` be itself a keymap,
rather than a function name, and have the resolver switch to such a keymap when
it encounters it\. There are some decisions to make about when to switch back to
the "normal" keymap for the current raga stack\-\-should probably look at how
`emacs` handles that\.

`vril`'s case is more complicated, though, because `d3w` and `d5b` and `2dd` are
all pretty much the same command \(delete\), with arguments \(motion and count\)\.
How does `emacs` `evil-mode` handle this?


### \[ \] Ragas, Zones, shifts

  Currently, we have one global raga for everything, and this is getting
increasingly annoying\.

We also handle shifting ragas in a sort of ad\-hoc fashion, which is going to
break badly as soon as we try to add a vril mode to go with nerf\.

What we need is some sort of controller, with a concept of focus, which Zone
is expecting to handle messages\.  It also needs an ability to dispatch to
other keymaps, relevant for MOUSE events in particular, as well as some
concept of which raga stack to switch to, and under what circumstances\.

This is **probably** the true primary responsibility of the "maestro", and the
mechanics of keymap/raga resolution may be part of it, or may be delegated to
a simple subcomponent, these are implementation details\. In any case, the
maestro may replace modeselektor as the first argument to handler functions\.

This is really the hard part, because to get it right also requires solving
some inadequacies in how we handle the concepts of Zones, Rainbufs, and so on\.

Just as we don't want ragas tied to keystrokes, we don't want rendering tied
to the concept of a raw xterm\.  Decoupling this will have numerous advantages,
starting with the ability to delegate our rendering logic to its own project
which other projects can then reuse\.

Other obvious ones: we can move Zones to multiple terminal processes, render
them in a browser or other GUI, and so on and so forth\.