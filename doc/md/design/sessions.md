# Sessions


At the time of writing, `helm` is quite a capable system\.

It has its limitations and rough edges, but it's a good repl, with
autocomplete for tables and a complete history of commands and their replies\.

It long ago passed the point where I'd want to develop in Lua in any other way\.

The next major system to bring online is sessions\.  I built `helm` to solve an
urgent problem, which is that a dynamic language which doesn't have a
comfortable repl is losing out on the better part of what makes dynamic
programming good\.

In Lisp circles, this is a truism\.  `helm` has a ways to go before it's truly
as polished and well\-integrated as a native Lisp repl\.  It has also made some
distinctive choices which have already paid off; notably, using a database to
store all interactions and their results, and the top\-line system, as
contrasted with the scroll\-based systems which are more common\.

Sessions arose out of a conversation with [Kartik Agaram](http://akkartik.name), in which
he said that in Mu, he was pursuing a system where interactive sessions within
the repl are turned into unit tests\.

Our sessions system will do exactly that, repaying the investment immediately
by allowing bridge developers to experiment at the `helm` \(as we are already
doing\) and transforming the acceptable results into unit and regression
tests\.


## Roadmap

Sessions is the last major piece of system software I intend to complete
before preparing `bridge` for general release\.

It has a bunch of little pieces that play together, with most of the
foundation already laid\.


- \#Tasks \[/\]:

  - [X]  Prepare a migration in the SQLite layer which backs `helm`\.

      I've started work on this; it might take some tries to get right, the
      migration framework itself is already in place\.

      This is the kind of system where you get the data structures right
      and everything else follows from there\.

  - [X]  Add a "macro mode" where a session is recorded and every line is
      marked as accepted\.  This is inflexible and somewhat painstaking to
      use, but it is the minimum viable system, and already useful as\-is\.

      This will also involve adding appropriate flags in `br` itself\.

  - [ ]  Use these sample sessions to build a headless `repl` which runs tests
      and reports the results\.

  - [ ]  Once we have a sessions framework, we make it shine by adding an
      interactive review mode\.  Still ironing out the details here, but it
      will allow the user to review the played session on quit, and assign
      to each line the values: `accept`, `reject`, `ignore`, and `skip`\.

      `accept` means that the answer to the given question is expected to
      remain the same\.  `reject` means the opposite: the answer isn't
      acceptable, the user intends to revisit the session after changing
      the code, until then it's a failing test\.  `ignore` means the answer
      isn't important, it's just a step that's needed to set up a test, and
      `skip` means that neither the line nor its effects are necessary and
      it should be omitted from the session entirely\.

      For `accept` and `reject` tests, this will provide an opportunity to
      add a description of the invariant the test upholds\.

  - [ ]  Most unit testing suites provide a collection of verbs useful for
      testing things\.  We don't rely on this to the same degree, since we
      can match any sort of return value, and we can do simple things like
      pinning the value of a single key through field access\.

      But we'll want some, so we start a repo which is pulled into the
      global namespace during sessions, to collect these useful verbs\.
      Some of these already live in `core`; `table.keys` and
      `table.collect` being two prime examples\.

  - [ ]  We need a way to share these tests, so a final task is implementing
      import and export for sessions\.  While we're in there, it would be
      good to leave some hooks for exporting and importing ordinary repl
      sessions\.

      The general premise of bridge is that the SQLite databases which back
      it can be directly synchronized through import and export, using our
      unwritten 0MQ stack\.  The first part of this is broadly implemented
      for modules, and we're starting to get to the point where there are
      enough databases that it might be useful to have a project for
      managing things like migrations and statement collections, as well as
      import and export generators, in a more controlled fashion\.

      The simplest version of this is simply to define an API in common and
      have handlers which implement it, and it might even be best to stick
      with that\.  SQL and Lua are excellent in their own domains, and
      mapping objects to relations is a notorious timesink\.
