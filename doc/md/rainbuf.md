# Rainbuf


This class encapsulates data to be written to the screen.


As it stands, we have two special cases, the ``txtbuf`` and ``results``.


We need to extend the functionality of ``results``, so we're building this as a
root metatable for those methods.


Plausibly, we can make this a 'mixin' for ``txtbuf`` as well, since they have
the additional complexity of receiving input.


## Design

We're aiming for complex interactivity with data.


Our current renderer is crude: it converts the entire table into a string
representation, including newlines, and returns it.


One sophistication we've added is a ``__repr`` metamethod, which overrides the
default use of ``ts()``.  It still returns a dumb block of strings, using
concatenation at the moment of combination.  This is inefficient and also
impedes more intelligent rendering.  But it's a start.


``rainbuf`` needs to have a cell-by-cell understanding of what's rendered and
what's not, must calculate a printable representation given the constraints of
the ``zone``, and, eventually, will respond to mouse and cursor events.


Doing this correctly is extraordinarily complex but we can fake it adequately
as long as the engineering is correct.  Everything we're currently using is
ASCII-range or emojis and both of those are predictable, narrow/ordinary and
wide respectively.


There are libraries/databases which purport to answer this question.  We plan
to link one of those in.


Results, as we currently manifest them, use an array for the raw objects and
``n`` rather than ``#res`` to represent the length.  That's a remnant of the
original repl from ``luv``.  The ``.n`` is neceessary because ``nil`` can be a
positional result.


A ``txtbuf`` keeps its contents in a ``.lines`` table, and so we can reuse this
field for cached textual representations.  All internals should support both
strings and array-of-strings as possible values of the ``lines`` array.


We also need a ``.wids`` array of arrays of numbers and should probably hide
this behind methods so as to fake it when we just have strings.


Later, we add a ``.targets``, this is a dense array for the number of lines,
each with a sparse array containing handlers for mouse events.  If a mouse
event doesn't hit a ``target`` then the default handler is engaged.


We also have ``offset``, a number, and ``more``, which is ``true`` if the buffer
continues past the edge of the zone and otherwise falsy.

#### includes

```lua
local repr = require "repr"
local ts, lineGen = repr.ts, repr.lineGen
```
#### Rainbuf metatable

```lua
local Rainbuf = meta {}
```
## Methods


### Rainbuf:lineGen(rows, offset)

This is a generator which yields ``rows`` number of lines.


Since we've replaced the old all-at-once ``repr`` with something that generates
a line at a time (and it only took, oh, six months), we're finally able to
generate these on the fly.

```lua
function Rainbuf.lineGen(rainbuf, rows, cols)
   offset = rainbuf.offset or 0
   cols = cols or 80
   if rainbuf.live then
      -- this buffer needs a fresh render each time
      rainbuf.reprs, rainbuf.lines = nil, nil
   end
   if not rainbuf.reprs then
      local reprs = {}
      for i = 1, rainbuf.n do
         if rainbuf.frozen then
            reprs[i] = string.lines(rainbuf[i])
         else
            reprs[i] = lineGen(rainbuf[i], cols)
            if type(reprs[i]) == "string" then
               reprs[i] = string.lines(reprs[i])
            end
         end
      end
      rainbuf.reprs = reprs
   end
   -- state for iterator
   local reprs = rainbuf.reprs
   local r_num = 1
   local cursor = 1 + offset
   rows = rows + offset
   if not rainbuf.lines then
      rainbuf.lines = {}
   end
   rainbuf.more = true
   local flip = true
   local function _nextLine()
      -- if we have lines, yield them
      if cursor < rows then
         if rainbuf.lines and cursor <= #rainbuf.lines then
            -- deal with line case
            cursor = cursor + 1
            return rainbuf.lines[cursor - 1]
         elseif rainbuf.more then
            local repr = reprs[r_num]
            if repr == nil then
               rainbuf.more = false
               return nil
            end
            assert(type(repr) == "function", "I see your problem")
            local line = repr()  -- #todo fix dead coroutine problem here
            if line ~= nil then
               rainbuf.lines[#rainbuf.lines + 1] = line
               if offset <= #rainbuf.lines then
                  cursor = cursor + 1
                  return line
               else
                  return _nextLine()
               end
            else
               r_num = r_num + 1
               return _nextLine()
            end
         end
      else
         return nil
      end
   end
   return _nextLine
end
```
### new(res?)

```lua
local function new(res)
   if type(res) == "table" and res.idEst == Rainbuf then
      error "made a Rainbuf from a Rainbuf"
   end
   local rainbuf = meta(Rainbuf)
   assert(res.n, "must have n")
   if res then
      for i = 1, res.n do
         rainbuf[i] = res[i]
      end
      rainbuf.n = res.n
      rainbuf.frozen = res.frozen
      rainbuf.live = res.live
   end
   -- these aren't in play yet
   rainbuf.wids  = {}
   rainbuf.offset = 0
   return rainbuf
end

Rainbuf.idEst = new

return new
```
