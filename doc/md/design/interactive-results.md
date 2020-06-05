# Interactive Results


The next major enhancement to the `helm` user interface involves
rearchitecting results printing to be an interactive process\.

Instead of expanding large tables by default, we'll have thresholds: for the
sake of argument, 12 non\-numeric key\-value pairs and 20 numeric\.  Exceeding
those thresholds will display the table as mostly\-folded: the first set of
values is followed by a `...` line\.

Clicking on that line will expand the table by some amount, up to fully\.
Clicking on or to the right of the opening `{` or `⟨{` will completely fold
it, turning it into the name form\.

Similarly, clicking on any unexpanded table will expand it in\-place\.


## \#Tasks \[/\]


### \[ \] \#Task  Move line concrescence from Composer to Rainbuf

We need to move the boundary between the Composer and the Rainbuf: Rainbufs
need to be able to handle partially composed lines, consisting of tables of
Tokens\.

This appears to be a two\-line change in `Composer:emit()`, and a
correspondingly modest alteration to the Rainbuf\.


### \[ \] \#Task  Build Targets for active zone areas

The Rainbuf also synthesizes a set of targets: zones based on these tokens
which can respond to mouse clicks by passing appropriate messages back to the
Rainbuf\.

I *think* these Targets should live inside Zones, and `act` simply hands all
mouse actions to the appropriate Zone\.  Zones are responsble for printing the
underlying information, so they have access to it, letting us do things like
reposition the cursor inside the Txtbuf\.


### \[ \] \#Task  Composer / tabulate must return coroutine generators

We need tables to return, not just Tokens, but cogenerators as provided in
`core`\.  This is a function which will produce a fresh tabulator for that
table whenever called\.

The Rainbuf is responsible for keeping `oncontract` and `onexpand` tables for
each Target, which perform cache invalidation and hold references to the
composition table for where expansions are to take place\.


### \[ \] \#Task  Right\-click to toggle \_\_repr and literal printing

It would be quite useful to be able to turn a given repr off and display the
underlying table\.  We can make this a simple right\-click, and revisit that if
we decide we want a menu of actions or some other, more complex interaction\.

That means the cogens need to come with a flag that tells a tabulator to
ignore `__repr` metamethods\.
