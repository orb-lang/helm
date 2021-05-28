# Rainbuf

This class encapsulates data to be written to the screen\.

As it stands, we have two special cases, the `txtbuf` and `results`\.

We need to extend the functionality of `results`, so we're building this as a
root metatable for those methods\.

Plausibly, we can make this a 'mixin' for `txtbuf` as well, since they have
the additional complexity of receiving input\.


## Design

We're aiming for complex interactivity with data\.

Our current renderer is crude: it converts the entire table into a string
representation, including newlines, and returns it\.

One sophistication we've added is a `__repr` metamethod, which overrides the
default use of `ts()`\.  It still returns a dumb block of strings, using
concatenation at the moment of combination\.  This is inefficient and also
impedes more intelligent rendering\.  But it's a start\.

`rainbuf` needs to have a cell\-by\-cell understanding of what's rendered and
what's not, must calculate a printable representation given the constraints of
the `zone`, and, eventually, will respond to mouse and cursor events\.

Doing this correctly is extraordinarily complex but we can fake it adequately
as long as the engineering is correct\.  Everything we're currently using is
ASCII\-range or emojis and both of those are predictable, narrow/ordinary and
wide respectively\.

There are libraries/databases which purport to answer this question\.  We plan
to link one of those in\.

Results, as we currently manifest them, use an array for the raw objects and
`n` rather than `#res` to represent the length\.  That's a remnant of the
original repl from `luv`\.  The `.n` is neceessary because `nil` can be a
positional result\.

A `txtbuf` keeps its contents in a `.lines` table, and so we can reuse this
field for cached textual representations\.  All internals should support both
strings and array\-of\-strings as possible values of the `lines` array\.

We also need a `.wids` array of arrays of numbers and should probably hide
this behind methods so as to fake it when we just have strings\.

Later, we add a `.targets`, this is a dense array for the number of lines,
each with a sparse array containing handlers for mouse events\.  If a mouse
event doesn't hit a `target` then the default handler is engaged\.

We also have `offset`, a number, and `more`, which is `true` if the buffer
continues past the edge of the zone and otherwise falsy\.


#### includes

```lua
local lineGen = import("repr:repr", "lineGen")
```


#### Rainbuf metatable

```lua
local Rainbuf = meta {}
```


## Methods


### Rainbuf:clearCaches\(\)

  Clears any cached lineGen iterators and their output, causing a full
re\-compose the next time lineGen is called\.

```lua
local clear = assert(table.clear)
function Rainbuf.clearCaches(rainbuf)
   clear(rainbuf.lines)
end
```


### Rainbuf:initComposition\(cols\)

Sets up the composition process with a line width of `cols`\.

```lua
local lines = import("core/string", "lines")
function Rainbuf.initComposition(rainbuf, cols)
   cols = cols or 80
   if rainbuf.scrollable then
      cols = cols - 3
   end
   -- If width is changing, we need a re-render
   -- "live" means re-render every time
   if cols ~= rainbuf.cols or rainbuf.live then
      rainbuf:clearCaches()
   end
   rainbuf.cols = cols
   rainbuf.more = true
end
```


### Rainbuf:composeOneLine\(\)

Composes one line and saves it to the cached `lines` array\.
Actual composition is delegated to an abstract method \_composeOneLine\.
Sets `more` to false and returns false if we are at the end of the content,
otherwise returns true\.

```lua
local insert = assert(table.insert)
function Rainbuf.composeOneLine(rainbuf)
   local line = rainbuf:_composeOneLine()
   if line then
      insert(rainbuf.lines, line)
      return true
   else
      rainbuf.more = false
      return false
   end
end
```


### Rainbuf:\_composeOneLine\(\)

Abstract method\. Generate the next line of content \(without caching it\),
returning nil if the available content is exhausted\.


### Rainbuf:composeUpTo\(line\_number\)

Attempts to compose at least `line_number` lines to the cached `lines` array\.
In order to correctly set `rainbuf.more`, we attempt to render
one additional line\.

```lua
function Rainbuf.composeUpTo(rainbuf, line_number)
   while rainbuf.more and #rainbuf.lines <= line_number do
      rainbuf:composeOneLine()
   end
   return rainbuf
end
```


### Rainbuf:composeAll\(\)

Renders all of our content to the cached `lines` array\.

```lua
function Rainbuf.composeAll(rainbuf)
   while rainbuf.more do
      rainbuf:composeOneLine()
   end
   return rainbuf
end
```


### Rainbuf:lineGen\(rows, cols\)

This is a generator which yields `rows` number of lines\.

Since we've replaced the old all\-at\-once `repr` with something that generates
a line at a time \(and it only took, oh, six months\), we're finally able to
generate these on the fly\.

```lua
function Rainbuf.lineGen(rainbuf, rows, cols)
   rainbuf:initComposition(cols)
   -- state for iterator
   local cursor = rainbuf.offset
   local max_row = rainbuf.offset + rows
   local function _nextLine()
      -- Off the end
      if cursor >= max_row then
         return nil
      end
      cursor = cursor + 1
      rainbuf:composeUpTo(cursor)
      local prefix = ""
      if rainbuf.scrollable then
         -- If this is the last line requested, but more are available,
         -- prepend a continuation marker, otherwise left padding
         prefix = "   "
         if cursor == max_row and rainbuf.more then
            prefix = a.red "..."
         end
      end
      return rainbuf.lines[cursor] and prefix .. rainbuf.lines[cursor]
   end
   return _nextLine
end
```


### Rainbuf:replace\(\[res\]\)

Replace the contents of the Rainbuf with those from res, emptying it if res is
nil\. We must clear any caches, and consider ourselves touched/changed\.

```lua
function Rainbuf.replace(rainbuf, res)
   rainbuf.value = res
   rainbuf:clearCaches()
   rainbuf.touched = true
end
```


### Rainbuf:scrollTo\(offset\)

Right now, just a setter for `.offset`, but we'll be moving `Zone:scrollTo()`
here soon\. For now, returns a boolean indicating whether scrolling occurred,
but I don't think we make any use of that\.\.\.

```lua
function Rainbuf.scrollTo(rainbuf, offset)
   if offset ~= rainbuf.offset then
      rainbuf.offset = offset
      rainbuf.touched = true
      return true
   else
      return false
   end
end
```


### Rainbuf:checkTouched\(\)

Answers whether the Rainbuf \(or its `source`, if it has one\) have been touched
since the last time this method was called, clearing the flag in the process\.

\#todo
be nice not to duplicate\.

```lua
function Rainbuf.checkTouched(rainbuf)
   if rainbuf.source and rainbuf.source:checkTouched() then
      rainbuf:replace(rainbuf.source.buffer_value)
   end
   local touched = rainbuf.touched
   rainbuf.touched = false
   return touched
end
```


### Rainbuf:\_init\(\)

Initialize the rainbuf immediately after creation\. Extracted from \_\_call
for easy extension\.

```lua
function Rainbuf._init(rainbuf)
   rainbuf.offset = 0
   rainbuf.lines = {}
   rainbuf.touched = false
end
```


### Rainbuf\(\[res\]\[, cfg\]\)

```lua
local Window = require "window:window"
local pget = assert(require "core:table" . pget)

function Rainbuf.__call(buf_class, res, cfg)
   if type(res) == "table" then
      if res.idEst == buf_class then
         return res
      -- #todo blech Window blows up on is_rainbuf. Do we really even need
      -- this assert? Or the early-out above for that matter?
      elseif pget(res, "is_rainbuf") then
         error("Trying to make a Rainbuf from another type of Rainbuf")
      end
   end
   local buf_M = getmetatable(buf_class)
   local rainbuf = setmetatable({}, buf_M)
   rainbuf:_init()
   -- #todo should check something else here--or just have mutually-exclusive
   -- parameters for source and value?
   if res and res.idEst == Window then
      rainbuf.source = res
      rainbuf:replace(res.buffer_value)
   else
      rainbuf:replace(res)
   end
   if cfg then
      for k, v in pairs(cfg) do
         rainbuf[k] = v
      end
   end
   return rainbuf
end
```


### Rainbuf:inherit\(\[cfg\]\)

Create a metatable for a "subclass" of Rainbuf\. Cribbed from Phrase:inherit\(\)\.

N\.B\. This will function against either an instance \(`Rainbuf():inherit()`\)
or the class itself \(`Rainbuf:inherit()`\), but in either case this is not true
prototype inheritance, only behavior on the Rainbuf metatable is inherited\.

```lua
local sub = assert(string.sub)
function Rainbuf.inherit(buf_class, cfg)
   local parent_M = getmetatable(buf_class)
   local child_M = setmetatable({}, parent_M)
   -- Copy metamethods because mmethod lookup does not respect =__index=es
   for k,v in pairs(parent_M) do
      if sub(k, 1, 2) == "__" then
         child_M[k] = v
      end
   end
   -- But, the new MT should have itself as __index, not the parent
   child_M.__index = child_M
   if cfg then
      -- this can override the above metamethod assignment
      for k,v in pairs(cfg) do
         child_M[k] = v
      end
   end
   return child_M
end
```


### Rainbuf:super\(method\_name\)

We mixin core:cluster\.super\.

```lua
Rainbuf.super = assert(require "core:cluster" . super)
```


### Rainbuf\.is\_rainbuf

We need a way to answer whether we are a Rainbuf **or any subclass**,
attach a property at this level similar to espalier:node\.

```lua
Rainbuf.is_rainbuf = true
```


```lua
local Rainbuf_class = setmetatable({}, Rainbuf)
Rainbuf.idEst = Rainbuf_class

return Rainbuf_class
```
