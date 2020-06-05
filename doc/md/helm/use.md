# Use

This is our superset of `require`, which can function as a drop\-in
replacement for it\.

That means it fulfils the interface: given a single string, it will search
package\.path, ignore singletons which have instances, and load the rest,
returning a single value\.

However, `use`, on entry into the global namespace, slaps a metatable on it\.
`use` clones the current global context and gives it a catch\-all \_\_newindex,
sets the fenv, calls the chunk, and returns all values\.

Since `require` only returns one, this can only break code which absorbs a
predicatble `nil` into a variable and then relies on it\.

`use` will also accept additional arguments\.  First we'll implement is a
table, where the \[0\] \(Djikstra\) element should be the package string, and
other constraints may be explicitly applied:

```lua-example
c, c_lib = use { "lib/clib",
                 version = "<=0.3.*"}
```

Note that we didn't use `local`\.  We hack the global metatable so that all
globals are registered locally, so we don't have to except inside functions\.

This will aid migration to Lun semantics\.  It's also just a lot cleaner, and
unlike a strict mode, it fixes the problem at load time, rather than just
pointing them out\.

This makes it impossible to tamper with the global namespace, because each
file receives its own custom \_G\.  `use` can return as many values as you would
like, so this in no way restricts elaboration of the outer context\.

It provides a consistent interface\.  You can read the last line of a `use`
module and know what values are available for assignment\.


### call graph

`use` will also retain an ordered call graph when `br` is called with the
`-i` flag\.  This allows the loop to respond to reloads by reloading anything
which could be changed by the library and re\-executing the entry point into
a fresh global context\.

