# Rainbuf


#NB In need of substantial revision in light of new classes.
``status = uv.write(table.concat(rainbuf))``.


Additionally, we want good estimates of size (but see below).  Displacement,
really, which is why we want to figure those things out as late as possible.


Rainbuf is a Phrase-like class with some awareness of what's an ANSI code and
what isn't.  Each array is a line, and also includes an array with the
displacement estimate.


Which is 0 for an ANSI sequence and otherwise varies.  Here we will pretend
that it's 1 cell per byte, which is unlikely to get us in trouble right away.


The utilities to determine displacement will probably go in ``anterm``. I have
a very general solution in mind.


To assist in this, we'll want to patch the ``anterm`` color metatable to return
a rainbuf.  The Phrase class takes whatever shape it's formed into, convenient
for AST generators.  A rainbuf is for painting an terminal, so concatenating
them always fills the leftmost.


I suspect I'm going to find, working with ``uv``, that there's seldom any
advantage in concatenating strings further out than about tokens.  Downsides,
really, since any "blagh " is the same string but a "blagh whuppy" and a
"blagh winkedy" are unique strings.


### Structure

Rainbufs are database-shaped.  The simplest ``r.idEst = Rainbuf`` is an
array of strings, with a second array, keyed as ``r.disp``, showing the expected
displacement of the string: That is, how far left (positive) or right
(negative) the cursor is expected to move on a given print.


This is equivalent to ``#tostring(r)`` for printable ASCII, and then starts to
diverge wildly.  Notably, any ANSI color sequence is of zero displacement.


Values of ``disp`` can either be numbers, in which case it is displacement by
column, or an array, in which case ``disp[0]`` is by column and ``disp[1]`` is by
row.  ``disp`` can also be a string. If so it must start with "?". If there are
additional characters it must be a signed integer value.


Rainbufs do **not** contain ``\n`` or ``\r``.  A rainbuf printer is expected to
perform newlining at the end of each rainbuf, respecting local context.  There
is no guarantee that the 1 position in a rainbuf is the 1 position on-screen.


Rainbufs can contain sequences of unknown displacement.  In such a case, the
displacement is _measured_ and recorded persistently in a database.


If we get the string "Hi! 🤪" it has a ``#`` of 8. So the disp will be "?8",
and the actual displacement turns out to be 6, correctly, and 5 on my tty,
which will double-print the emoji and the closing string!


Solving that quirk is a bit out of scope; the point is that we'll have an
estimation engine, and that all it needs to do right now is distinguish color
sequences (0) and text (#str).  Usually the ``wc_width()`` will be correct, and
measurement will be to compensate for terminals not knowing what they've done.


A rainbuf that contains strings as array members may **only** have strings as
array members.  This is called a line, and a rainbuf which contains a line
as an array member may **only** have lines as members.


These we call blocks. Every aggregate beyond this is also a block, and there
is no limit on these levels of detail, but every rainbuf member of a block
must have the same depth, so that in all cases, the same number of lookups
lead to a string.


In code these distinctions are made with a single field ``d``, an unsigned
integer.  Lines have a ``d`` of one, ``d = 0`` is the strings themselves.


There will be other fields; rainbuf is the last stop before the terminal, and
needs to convey various hints to the renderer so that e.g. mouse targets line
up with the correct regions.  It is cleaner for things like elided blocks to
live in the rainbuf than to be synced by the renderer.


I think.  Because we're operating on an event loop, the rainbuf has to both
soley own write access to itself, and only lend out one read pointer after
an atomic update.  That implies two different views must be separate rainbufs
fed from the same quipu, and renderers are rainbuf interpreters.
