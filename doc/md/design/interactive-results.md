# Interactive Results


The next major enhancement to the ``helm`` user interface involves
rearchitecting results printing to be an interactive process.


Instead of expanding large tables by default, we'll have thresholds: for the
sake of argument, 12 non-numeric key-value pairs and 20 numeric.  Exceeding
those thresholds will display the table as mostly-folded: the first set of
values is followed by a ``...`` line.


Clicking on that line will expand the table by some amount, up to fully.
Clicking on or to the right of the opening ``{`` or ``⟨{`` will completely fold
it, turning it into the name form.


Similarly, clicking on any unexpanded table will expand it in-place.


## Implications

We need to move the boundary between the Composer and the Rainbuf: Rainbufs
need to be able to handle partially composed lines, consisting of tables of
Tokens.

#Task Move line concrescence from Composer to Rainbuf.