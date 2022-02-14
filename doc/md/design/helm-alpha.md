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

I'm going to start with the principles that will define this architecture in
its complete form\.


###
