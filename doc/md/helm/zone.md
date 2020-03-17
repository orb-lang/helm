# Zone


We need to get a lot more intelligent about how we write to the screen.


``Zone`` is our metatable for handling these regions.  It's a tricky bit of
engineering and something I've never really done before.


The result we want is to have a single ``modeS:refresh()`` called at the end of
each action, which repaints the screen.  A Zone is either affected or it
isn't; if it is, we repaint the whole Zone, if not, nothing.


Zones have a ``.z`` axis, starting with 1, and monotonically increasing. I
expect to use ``.z == 2`` and leave it at that, for now, but we want to
be able to stack as well as tile, at some point.


We'll want a ``zoneherder`` of some sort to manage zone changes. Each Z plane
has to have non-overlapping Zones, and ``1`` should be completely tiled. The
zoneherder propagates adjustments.


A paint message to a Zone will be a ``rainbuf``.  There are a few tricky things
here, and ultimately we'll need a Unicode database to chase down all the
edges.  We need to engineer the system so that it can use that info when the
time comes.


The Zone needs to stay in its lane, basically, so we need to know when we've
reached the edges.  When we start to add mouse clicks, we have to know what
the mouse has targeted, so Zones will receive mouse messages also.


This is the next major push for ``helm``, and when it's complete I'll be ready
to show it off.  It's a significant piece of engineering and I'm thinking I
need to shore up Orb a bit to get there.


Specifically, I need the ability to add a plantUML pipeline to the doc
generator, and maybe cut the apron strings with respect to Markdown and public
hosting.


This is a delicate point in the boot process.  ``helm`` needs to be able to
interact with an already-running bridge/luv process, as it stands the two
event loops will collide.  ``orb`` only runs an event loop with ``orb serve`` so
the next step with ``helm`` proper is to set it up locally to run as a ``repl``
on plain ordinary ``br`` programs, so I can use all this carefully won tooling
on the other parts of the programme.


## Design

This file is going to have both the ``zoneherd``, called ``modeS.zones``, and
a ``Zone`` metatable for handling single Zones.


The Zone herd will need to hold zones by name as well as by index, because
we want to repaint in a specific order (pre-sorting by ``.z``) and pass messages
by name, so that we send a result to ``modeS.zones.result``.


We'll need methods for reflowing, for creating, and for refreshing.  Each
``Zone`` will have a ``.touched`` field and if it's flipped we repaint; if there's
an overlapping Zone of higher ``z`` we flip its touched bit as well.


A ``Zone`` needs an ``onMouse`` method that receives the whole packet and acts
accordingly.  The flow hands every input including parsed mouse messages to
the ``modeselektor``, and some, particularly scrolls, are handled there. The
rest are assigned by the zone herder, which sould probably normalize the
action so, for example, a click in the upper left corner of a Zone is ``1,1``.


Since the hard part is repainting, I'll start with reflow, and just hard-
switch the REPL to a 'reflow mode' that just draws characters to a screen,
then add a popup.

```lua
local Txtbuf = require "helm/txtbuf"
local Rainbuf = require "helm/rainbuf"
local a = require "anterm:anterm"

local instanceof = import("core/meta", "instanceof")
```
```lua
local Zone = meta {}
local Zoneherd = meta {}
```
## Zone methods


### Zone:height(), Zone:width()

```lua
function Zone.height(zone)
   return zone.br - zone.tr + 1
end

function Zone.width(zone)
   return zone.bc - zone.tc + 1
end
```
### Zone:replace(zone, contents)

Replaces the contents of the zone with the provided value.

```lua
function Zone.replace(zone, contents)
   zone.contents = contents or ""
   zone.touched = true

   return zone
end
```
### Zone:scrollUp(), Zone:scrollDown()

Scrolls the contents of the Zone by one line. Marks the zone as touched
and answers true if scrolling occurred, otherwise false. Only works if
the contents is a Rainbuf (which handles the actual scrolling).

```lua

function Zone.scrollUp(zone)
   if instanceof(zone.contents, Rainbuf)
      and zone.contents:scrollUp() then
      zone.touched = true
      return true
   else
      return false
   end
end

function Zone.scrollDown(zone)
   if instanceof(zone.contents, Rainbuf)
      and zone.contents:scrollDown() then
      zone.touched = true
      return true
   else
      return false
   end
end
```
### Zone:set(tc, tr, bc, br)

Updates the bounds of the zone, marking it as touched if they actually change.

```lua
function Zone.set(zone, tc, tr, bc, br)
   assert(tc <= bc, "tc: " .. tc .. ", bc: " .. bc)
   assert(tr <= br, "tr: " .. tr .. ", br: " .. br)
   if not(zone.tr == tr and
          zone.tc == tc and
          zone.br == br and
          zone.bc == bc) then
      -- If zone width is changing, clear caches of the contained Rainbuf
      -- Note that :set() is called to set zone.(tc,bc,tr,br) for the first time,
      -- so we only check for a change if there are previous values
      if zone.bc and zone.tc
         and (bc - tc) ~= (zone.bc - zone.tc)
         and instanceof(zone.contents, Rainbuf) then
         zone.contents:clearCaches()
      end
      zone.tr = tr
      zone.tc = tc
      zone.br = br
      zone.bc = bc
      zone.touched = true
   end
   return zone
end
```
### _writeLines(write, zone, str)

```lua
local lines = import("core/string", "lines")

local function _writeLines(write, zone, str)
   local nl = a.col(zone.tc) .. a.jump.down(1)
   local pr_row = zone.tr
   for line in lines(str) do
       write(line)
       write(nl)
       pr_row = pr_row + 1
       if pr_row > zone.br then
          break
       end
   end
end
```
### _renderRainbuf

Render the zone contents as a Rainbuf, wrapping them **in** a Rainbuf if needed.

```lua
local instanceof = import("core/meta", "instanceof")

local function _renderRainbuf(write, zone)
   if not zone.contents then
      return nil
   end
   assert(instanceof(zone.contents, Rainbuf))
   local nl = a.col(zone.tc) .. a.jump.down(1)
   for line in zone.contents:lineGen(zone:height(), zone:width()) do
      write(line)
      write(nl)
   end
end
```
### _renderTxtbuf(modeS, zone)

```lua
local concat = assert(table.concat)
local c = import("singletons/color", "color")
local Token = require "helm/repr/token"

local function _renderTxtbuf(modeS, zone, write)
   local tokens = modeS.lex(zone.contents)
   for i, tok in ipairs(tokens) do
      -- If suggestions are active and one is highlighted,
      -- display it in grey instead of what the user has typed so far
      -- Note this only applies once Tab has been pressed, as until then
      -- :selectedItem() will be nil
      if tok.cursor_offset and modeS.suggest.active_suggestions
         and modeS.suggest.active_suggestions[1]:selectedItem() then
         tok = Token(modeS.suggest.active_suggestions[1]:selectedItem(), c.base)
      end
      tokens[i] = tok:toString(c)
   end
   _writeLines(write, zone, concat(tokens))
end
```
## Zoneherd methods


### Zoneherd:newZone(name, tc, tr, bc, br, z, debug_mark)

Creates a new zone and adds it to the Zoneherd.

```lua
local function newZone(name, tc, tr, bc, br, z, debug_mark)
   local zone = meta(Zone)
   zone.name = name
   zone.debug_mark = debug_mark
   zone.z = z
   zone:set(tc, tr, bc, br)
   zone.touched = false
   -- zone.contents, aspirationally a rainbuf, is provided later
   return zone
end

function Zoneherd.newZone(zoneherd, name, tc, tr, bc, br, z, debug_mark)
   zoneherd[name] = newZone(name, tc, tr, bc, br, z, debug_mark)
   -- this doesn't account for Z axis but for now:
   zoneherd[#zoneherd + 1] = zoneherd[name]
   -- todo: make a Zoneherd:add(zone, name) that handles z-ordering
   -- and auto-adjusts proportionally.
   return zoneherd
end
```
#### _zoneOffset(modes)

```lua
local function _zoneOffset(modeS)
   if modeS.max_col <= 80 then
      return 20
   elseif modeS.max_col <= 100 then
      return 30
   elseif modeS.max_col <= 120 then
      return 40
   else
      return 50
   end
end
```
### Zoneherd:reflow(modeS)

```lua
function Zoneherd.reflow(zoneherd, modeS)
   local right_col = modeS.max_col - _zoneOffset(modeS)
   local txt_off = modeS:continuationLines()
   zoneherd.status:set(1, 1, right_col, 1)
   zoneherd.prompt:set(  1,
                         modeS.repl_top,
                         modeS.l_margin - 1,
                         modeS.repl_top + txt_off)
   zoneherd.command:set( modeS.l_margin,
                         modeS.repl_top,
                         right_col,
                         modeS.repl_top + txt_off )
   zoneherd.results:set( 1,
                         modeS.repl_top + txt_off + 1,
                         right_col,
                         modeS.max_row )
   zoneherd.stat_col:set( right_col + 1,
                          1,
                          modeS.max_col,
                          1 )
   zoneherd.suggest:set( right_col + 1,
                         modeS.repl_top + 1,
                         modeS.max_col,
                         modeS.max_row )
   return zoneherd
end
```
### Zoneherd:paint(modeS)

Once again we pass a reference to the ``modeselektor`` to get access to things
like the lexer.

```lua

function Zoneherd.paint(zoneherd, modeS)
   local write = zoneherd.write
   write(a.cursor.hide(), a.clear())
   for i, zone in ipairs(zoneherd) do
      if zone.touched then
         -- erase
         write(a.erase.box( zone.tc,
                            zone.tr,
                            zone.bc,
                            zone.br ),
               a.colrow(zone.tc, zone.tr))
         -- actually render ze contents
         if type(zone.contents) == "string" then
            _writeLines(write, zone, zone.contents)
         elseif type(zone.contents) == "table"
            and zone.contents.idEst == Txtbuf then
            _renderTxtbuf(modeS, zone, write)
         else
            _renderRainbuf(write, zone)
         end
         zone.touched = false
      end
   end
   modeS:placeCursor()
   write(a.cursor.show())
   return zoneherd
end
```
### new

Makes a Zoneherd.  Borrows the modeselektor to get proportions, but returns
the zoneherd, which is assigned to its slot on the modeselector at the call
site, for consistency.


Most of this code needs to be in the ``reflow`` method; ``new`` should allocate
and then reflow.

```lua
local function new(modeS, writer)
   local zoneherd = meta(Zoneherd)
   zoneherd.write = writer
   -- make Zones
   -- correct values are provided by reflow
   zoneherd:newZone("status", -1, -1, -1, -1, 1, ".")
   zoneherd:newZone("stat_col", -1, -1, -1, -1, 1, "!")
   zoneherd:newZone("prompt", -1, -1, -1, -1, 1, ">")
   zoneherd:newZone("command", -1, -1, -1, -1, 1, "$")
   zoneherd:newZone("gutter", -1, -1, -1, -1, 1, "_")
   zoneherd:newZone("results", -1, -1, -1, -1, 1, "~")
   zoneherd:newZone("suggest", -1, -1, -1, -1, 1, "%")
   zoneherd:reflow(modeS)

   return zoneherd
end
```
```lua
return new
```
