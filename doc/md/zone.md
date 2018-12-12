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


This is the next major push for ``femto``, and when it's complete I'll be ready
to show it off.  It's a significant piece of engineering and I'm thinking I
need to shore up Orb a bit to get there.


Specifically, I need the ability to add a plantUML pipeline to the doc
generator, and maybe cut the apron strings with respect to Markdown and public
hosting.


This is a delicate point in the boot process.  ``femto`` needs to be able to
interact with an already-running bridge/luv process, as it stands the two
event loops will collide.  ``orb`` only runs an event loop with ``orb serve`` so
the next step with ``femto`` proper is to set it up locally to run as a ``repl``
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
assert(meta)

local concat = assert(table.concat)

local Txtbuf = require "txtbuf"

local Rainbuf = require "rainbuf"

local Zone = meta {}

local Zoneherd = meta {}
```
### _collide(zone_a, zone_b)

#Deprecated#NB I'm starting to think this entire notion is ill-conceived, this is```lua
function _inside(col, row, zone)
   return (col >= zone.tc)
     and  (col <= zone.bc)
     and  (row >= zone.tr)
     and  (row <= zone.br)
end

function _collide(z_a, z_b)
   if z_a.z ~= z_b.z then
      -- this is just 'false' but let's refactor that when it's time
      return {false, false, false, false}, false, {false, false}
   end

   local collision = false
   -- clockwise from top left
   local z_a_corners = { {z_a.tc, z_a.tr},
                         {z_a.bc, z_a.tr},
                         {z_a.bc, z_a.br},
                         {z_a.tc, z_a.br} }
   local hits = {}
   for i, corner in ipairs(z_a_corners) do
      local hit = _inside(corner[1], corner[2], z_b)
      if hit then
         collision = true
      end
      hits[i] = hit
   end
   local a_left_of_b = z_a.tc < z_b.tc
   local a_above_b = z_a.tr < z_b.tr
   -- bottom of a over top of b
   if (hits[3] or hits[4]) and a_above_b then
      z_b.tr = z_a.br + 1
   end
   -- right of a over left of b
   if (hits[2] or hits[3]) and a_left_of_b then
      z_b.tc = z_a.bc + 1
   end
   -- top of a over bottom of b
   if (hits[1] or hits[2]) and not a_above_b then
      z_b.br = z_a.tr - 1
   end
   -- left of a over right of b
   if (hits[1] or hits[4]) and not a_left_of_b then
      z_b.bc = z_a.tc - 1
   end
   return hits, collision, {a_left_of_b, a_above_b}
end
```
### _collideAll(zoneherd, zone)

Collides a given zone with the rest of the herd.


Called after an ``adjust`` to resettle matters.

```lua
local function _collideAll(zoneherd, zone)
   for i, z in ipairs(zoneherd) do
      if zone ~= z then
         _collide(zone, z)
      end
   end
end
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
### Zone:replace(zone, rainbuf)

```lua
function Zone.replace(zone, rainbuf)
   zone.contents = rainbuf
   zone.touched = true

   return zone
end
```
### Zone:set(tc, tr, bc, br)

```lua
function Zone.set(zone, tc, tr, bc, br)
   zone.tc = tc
   zone.tr = tr
   zone.bc = bc
   zone.br = br
   return zone
end
```
### _writeLines(write, zone, str)

```lua
local lines = assert(string.lines, "string.lines must be provided")

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
### _writeResults

We'll special-case the results buffer for now.

```lua
local function _writeResults(write, zone, new)
   local rainbuf = {}
   local row = zone.tr
   local results = zone.contents
   if not results then
      return nil
   end
   if results.idEst ~= Rainbuf then
      results = Rainbuf(results)
   end
   local nl = a.col(zone.tc) .. a.jump.down(1)
   for line in results:lineGen(zone:height() + 1) do
      write(line)
      write(nl)
   end
end
```
### _renderTxtbuf(modeS, zone)

```lua
local function _renderTxtbuf(modeS, zone, write)
   local lb = modeS.lex(tostring(zone.contents))
   if type(lb) == "table" then
      lb = concat(lb)
   end
   write(a.colrow(zone.tc, zone.tr))
   _writeLines(write, zone, lb)
end
```
## Zoneherd methods


### Zoneherd:newZone(name, tc, tr, bc, br, z, debug_mark)

```lua
function Zoneherd.newZone(zoneherd, name, tc, tr, bc, br, z, debug_mark)
   zoneherd[name] = newZone(tc, tr, bc, br, z, debug_mark)
   -- this doesn't account for Z axis but for now:
   zoneherd[#zoneherd + 1] = zoneherd[name]
   -- todo: make a Zoneherd:add(zone, name) that handles z-ordering
   -- and auto-adjusts proportionally.
   return zoneherd
end
```
### Zoneherd:adjust(zoneherd, zone, delta, bottom)

This adjusts the boundaries of a specific zone.


Collides as well

#deprecated there are subtle logic bugs (that probably aren't subtle once
  - zoneherd: The ``Zoneherd``
  - zone:  The ``Zone``
  - delta:  A table, {col, row}, may be positive or negative
  - bottom:  A boolean, if true, delta is for the bottom right,
             false or nil, top left.
- #Return: zoneherd

```lua-noknit
function Zoneherd.adjust(zoneherd, zone, delta, bottom)
   if not bottom then
      zone.tc = zone.tc + delta[1]
      zone.tr = zone.tr + delta[1]
   else
      zone.bc = zone.bc + delta[1]
      zone.br = zone.br + delta[2]
   end

   _collideAll(zoneherd, zone)
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
### Zoneherd:adjustCommand(zoneherd, delta)

```lua
function Zoneherd.adjustCommand(zoneherd)
   local lines = zoneherd.command.contents and zoneherd.command.contents.lines
   local txt_off = lines and #lines -1 or 0
   zoneherd.command.br = zoneherd.command.tr + txt_off
   zoneherd.results.tr = zoneherd.command.br + 1
   return zoneherd
end
```
### Zoneherd:reflow(modeS)

```lua
function Zoneherd.reflow(zoneherd, modeS)
   local right_col = modeS.max_col - _zoneOffset(modeS)
   local txt_off = modeS.txtbuf and #modeS.txtbuf.lines - 1 or 0
   zoneherd.status:set(1, 1, right_col, 1)
   zoneherd.command:set( modeS.l_margin,
                         modeS.repl_top,
                         right_col,
                         modeS.repl_top + txt_off )
   zoneherd.prompt:set(1, 2, modeS.l_margin - 1, 2)
   zoneherd.results:set( modeS.l_margin,
                         modeS.repl_top + txt_off + 1,
                         right_col,
                         modeS.max_row )
   zoneherd.stat_col:set( right_col + 1,
                          1,
                          modeS.max_col,
                          1 )
   zoneherd.suggest:set( right_col + 1,
                         3,
                         modeS.max_col,
                         modeS.max_row )
   for _,z in ipairs(zoneherd) do
      z.touched = true
   end
   return zoneherd
end
```
### Zoneherd:paint(modeS)

Once again we pass a reference to the ``modeselektor`` to get access to things
like the lexer.



```lua
local a = require "anterm"

local _hard_nl = a.col(1) .. a.jump.down()

local function _paintGutter(zoneherd)
   local write = zoneherd.write
   local lines = zoneherd.command.contents
                 and #zoneherd.command.contents.lines - 1 or 0
   write(a.erase._box(1, 3, zoneherd.results.tc - 1, zoneherd.results.br))
   write(a.colrow(1,3))
   while lines > 0 do
      write "..."
      write(_hard_nl)
      lines = lines - 1
   end
   local results = zoneherd.results.contents
   if type(results) == "table" and results.more then
      write(a.colrow(1, zoneherd.results.br))
      write(a.red "...")
   end
end

function Zoneherd.paint(zoneherd, modeS, all)
   local write = zoneherd.write
   write(a.cursor.hide())
   write(a.clear())
   if all then
      write(a.erase.all())
   end
   for i, zone in ipairs(zoneherd) do
      if zone.touched or all then
         -- erase
         write(a.erase._box(    zone.tc,
                                zone.tr,
                                zone.bc,
                                zone.br ))
         write(a.colrow(zone.tc, zone.tr))
         -- actually render ze contents
         if type(zone.contents) == "string" then
            zoneherd.write(zone.contents)
         elseif type(zone.contents) == "table"
            and zone.contents.idEst == Txtbuf then
            _renderTxtbuf(modeS, zone, write)
         elseif zone == zoneherd.results then
            _writeResults(write, zone)
         end
         zone.touched = false
      end
   end
   zoneherd.write(a.cursor.show())
   _paintGutter(zoneherd)
   modeS:placeCursor()
   return zoneherd
end
```
### newZone(tr, tc, br, bc, z, debug_mark)

This creates a new Zone.

```lua
local function newZone(tc, tr, bc, br, z, debug_mark)
   assert(tc <= bc, "tc: " .. tc .. ", bc: " .. bc)
   assert(tr <= br, "tr: " .. tr .. ", br: " .. br)
   local zone = meta(Zone)
   zone:set(tc, tr, bc, br)
   zone.debug_mark = debug_mark
   zone.z = z
   zone.touched = false
   -- zone.contents, aspirationally a rainbuf, is provided later
   return zone
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
   local right_col = modeS.max_col - _zoneOffset(modeS)
   zoneherd.write = writer
   -- make Zones
   -- correct values are provided by reflow
   zoneherd.status  = newZone(-1, -1, -1, -1, 1, ".")
   zoneherd[1] = zoneherd.status
   zoneherd.command = newZone(-1, -1, -1, -1, 1, "|")
   zoneherd[3] = zoneherd.command
   zoneherd.prompt  = newZone(-1, -1, -1, -1, 1, ">")
   zoneherd[2] = zoneherd.prompt
   zoneherd.results = newZone(-1, -1, -1, -1, 1, "~")
   zoneherd[4] = zoneherd.results
   zoneherd.stat_col = newZone(-1, -1, -1, -1, 1, "!")
   zoneherd[5] = zoneherd.stat_col
   zoneherd.suggest = newZone(-1, -1, -1, -1, 1, "%")
   zoneherd[6] = zoneherd.suggest
   zoneherd:reflow(modeS)

   return zoneherd
end
```
```lua
return new
```