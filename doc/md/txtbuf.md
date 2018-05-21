# Txtbuf

We're not going to have one of these right away.


This is not much more than an ordinary array of lines that has a bit of
awareness, mostly about which lines have cursors and which don't.


I'll circle back for quipu but I want a basic editor as soon as possible. The
interaction dynamics need to be worked out right away, plus I want to use it!


Plan: A line that has a cursor on it, and there can be many, gets 'opened'
into a grid of characters.  These in turn get 'closed' when the cursor leaves.


A closed line is just a string.
