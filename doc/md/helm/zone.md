# Zone


We need to get a lot more intelligent about how we write to the screen\.

`Zone` is our metatable for handling these regions\.  It's a tricky bit of
engineering and something I've never really done before\.

The result we want is to have a single `modeS:refresh()` called at the end of
each action, which repaints the screen\.  A Zone is either affected or it
isn't; if it is, we repaint the whole Zone, if not, nothing\.

Zones have a `.z` axis, starting with 1, and monotonically increasing\. I
expect to use `.z == 2` and leave it at that, for now, but we want to
be able to stack as well as tile, at some point\.

We'll want a `zoneherder` of some sort to manage zone changes\. Each Z plane
has to have non\-overlapping Zones, and `1` should be completely tiled\. The
zoneherder propagates adjustments\.

A paint message to a Zone will be a `rainbuf`\.  There are a few tricky things
here, and ultimately we'll need a Unicode database to chase down all the
edges\.  We need to engineer the system so that it can use that info when the
time comes\.

The Zone needs to stay in its lane, basically, so we need to know when we've
reached the edges\.  When we start to add mouse clicks, we have to know what
the mouse has targeted, so Zones will receive mouse messages also\.

This is the next major push for `helm`, and when it's complete I'll be ready
to show it off\.  It's a significant piece of engineering and I'm thinking I
need to shore up Orb a bit to get there\.

Specifically, I need the ability to add a plantUML pipeline to the doc
generator, and maybe cut the apron strings with respect to Markdown and public
hosting\.

This is a delicate point in the boot process\.  `helm` needs to be able to
interact with an already\-running bridge/luv process, as it stands the two
event loops will collide\.  `orb` only runs an event loop with `orb serve` so
the next step with `helm` proper is to set it up locally to run as a `repl`
on plain ordinary `br` programs, so I can use all this carefully won tooling
on the other parts of the programme\.


## Design

This file is going to have both the `zoneherd`, called `modeS.zones`, and
a `Zone` metatable for handling single Zones\.

The Zone herd will need to hold zones by name as well as by index, because
we want to repaint in a specific order \(pre\-sorting by `.z`\) and pass messages
by name, so that we send a result to `modeS.zones.result`\.

We'll need methods for reflowing, for creating, and for refreshing\.  Each
`Zone` will have a `.touched` field and if it's flipped we repaint; if there's
an overlapping Zone of higher `z` we flip its touched bit as well\.

A `Zone` needs an `onMouse` method that receives the whole packet and acts
accordingly\.  The flow hands every input including parsed mouse messages to
the `modeselektor`, and some, particularly scrolls, are handled there\. The
rest are assigned by the zone herder, which sould probably normalize the
action so, for example, a click in the upper left corner of a Zone is `1,1`\.

Since the hard part is repainting, I'll start with reflow, and just hard\-
switch the REPL to a 'reflow mode' that just draws characters to a screen,
then add a popup\.

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


### Zone:height\(\), Zone:width\(\)

```lua
function Zone.height(zone)
   return zone.br - zone.tr + 1
end

function Zone.width(zone)
   return zone.bc - zone.tc + 1
end
```

### Zone:clientHeight\(\), Zone:clientWidth\(\)

As `:height()` and `:width()`, but takes into account the space occupied by
a border, if we have one\.

```lua
function Zone.clientHeight(zone)
   if zone.border then
      return zone:height() - 2
   else
      return zone:height()
   end
end

function Zone.clientWidth(zone)
   if zone.border then
      return zone:width() - 2
   else
      return zone:width()
   end
end
```

### Zone:borderThickness\(\)

Answers the thickness of the zone border\-\-right now just 0 or 1\.

```lua
function Zone.borderThickness(zone)
   return zone.border and 1 or 0
end
```

### Zone:overlaps\(other\_zone\)

Determines whether there is any overlap between two zones,
irrespective of their z\-values\-\-answers whether they affect any of
the same cells on screen\.

```lua
function Zone.overlaps(zone, other_zone)
   -- The other zone may be uninitialized--treat this as nonoverlapping
   if not (other_zone.tc and other_zone.tr and
           other_zone.bc and other_zone.br) then
      return false
   end
   return zone.tc <= other_zone.bc and
          zone.bc >= other_zone.tc and
          zone.tr <= other_zone.br and
          zone.br >= other_zone.tr
end
```

### Zone:replace\(contents\)

Replaces the contents of the zone with the provided value\.

```lua
function Zone.replace(zone, contents)
   zone.contents = contents or ""
   zone:beTouched()
   return zone
end
```

### Scrolling

#### Zone:scrollTo\(offset, allow\_overscroll\)

Main scrolling method\. Scrolls the contents of the Zone to start `offset`
lines into the underlying content\.

`allow_overscroll` determines whether we are willing to scroll past the
available content\. If falsy, scrolling stops when the last line of content
is the last line on the screen\. If truthy, scrolling stops when the last
line of content is the **first** line on the screen\.

Returns a boolean indicating whether any scrolling occurred\.

Depends on the zone contents being a Rainbuf
\(which handles the actual scrolling\)\.

```lua
local bound = import("core/math", "bound")
local instanceof = import("core/meta", "instanceof")
function Zone.scrollTo(zone, offset, allow_overscroll)
   if not instanceof(zone.contents, Rainbuf) then
      return false
   end
   -- Try to render the content that will be visible after the scroll
   zone.contents:composeUpTo(offset + zone:height())
   local required_lines_visible = allow_overscroll and 1 or zone:height()
   offset = bound(offset, 0, #zone.contents.lines - required_lines_visible)
   if offset ~= zone.contents.offset then
      zone.contents.offset = offset
      zone:beTouched()
      return true
   else
      return false
   end
end
```

#### Zone:scrollBy\(delta, allow\_overscroll\)

Relative scrolling operation\. Change the scroll position by `delta` line\(s\)\.

```lua
function Zone.scrollBy(zone, delta, allow_overscroll)
   -- Need to check this here even though :scrollTo already does
   -- because we talk to the Rainbuf to figure out the new offset
   if not instanceof(zone.contents, Rainbuf) then
      return false
   end
   return zone:scrollTo(zone.contents.offset + delta, allow_overscroll)
end
```

#### Zone:scrollUp\(\), :scrollDown\(\), :pageUp\(\), :pageDown\(\)

Helpers for common scrolling operations\.

```lua
function Zone.scrollUp(zone)
   return zone:scrollBy(-1)
end
function Zone.scrollDown(zone)
   return zone:scrollBy(1)
end

function Zone.pageUp(zone)
   return zone:scrollBy(-zone:height())
end
function Zone.pageDown(zone)
   return zone:scrollBy(zone:height())
end

local floor = assert(math.floor)
function Zone.halfPageUp(zone)
   return zone:scrollBy(-floor(zone:height() / 2))
end
function Zone.halfPageDown(zone)
   return zone:scrollBy(floor(zone:height() / 2))
end
```

#### Zone:scrollToTop\(\), Zone:scrollToBottom\(allow\_overscroll\)

Scroll to the very beginning or end of the content\.
Beginning is easy, end is a little more interesting, as we have to first
render all the content \(in order to know how much there is\), then account
for allow\_overscroll in deciding how far to go\.

```lua
function Zone.scrollToTop(zone)
   return zone:scrollTo(0)
end

function Zone.scrollToBottom(zone, allow_overscroll)
   zone.contents:composeAll()
   -- Choose a definitely out-of-range value,
   -- which scrollTo will bound appropriately
   return zone:scrollTo(#zone.contents.lines, allow_overscroll)
end
```

### Zone:setBounds\(tc, tr, bc, br\)

Updates the bounds of the zone, marking it as touched if they actually change\.

```lua
function Zone.setBounds(zone, tc, tr, bc, br)
   assert(tc <= bc, "tc: " .. tc .. ", bc: " .. bc)
   assert(tr <= br, "tr: " .. tr .. ", br: " .. br)
   if not(zone.tr == tr and
          zone.tc == tc and
          zone.br == br and
          zone.bc == bc) then
      -- If zone width is changing, clear caches of the contained Rainbuf
      -- Note that :setBounds() is called to set zone.(tc,bc,tr,br) for the first time,
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
      -- #todo technically this is incomplete as we need to care about
      -- cells we may previously have owned and no longer do, and what zones
      -- *are* now responsible for them. Doing that properly requires a real
      -- two-step layout process, though (figure out where everything is going
      -- to be, *then* put it there and mark things touched), so we'll
      -- hold off for now
      zone:beTouched()
   end
   return zone
end
```

### Zone:setVisibility\(new\_visibility\), Zone:show\(\), Zone:hide\(\)

```lua
function Zone.setVisibility(zone, new_visibility)
   if new_visibility ~= zone.visible then
      zone.visible = new_visibility
      zone:beTouched()
   end
   return zone
end

function Zone.show(zone)
   return zone:setVisibility(true)
end
function Zone.hide(zone)
   return zone:setVisibility(false)
end
```

### Zone:beTouched\(\)

Marks a zone as touched, also marking others that may be affected based
on overlap\. If `zone` is visible, this is any overlapping zones above it,
which may need to repaint to occlude it\. If `zone` is hidden, this is
overlapping zones below it, which \(if it is **newly** hidden\) may be revealed\.
We assume that zones of equal z do not overlap, so we don't check
in that case \(which handily excludes the originating zone itself\)

```lua
function Zone.beTouched(zone)
   if zone.touched then return end
   zone.touched = true
   for _, other_zone in ipairs(zone.zoneherd) do
      if zone.z ~= other_zone.z and
         zone.visible == (other_zone.z > zone.z) and
         zone:overlaps(other_zone) then
         other_zone.touched = true
      end
   end
end
```

### \_writeLines\(write, zone, str\)

```lua

local function _nl(zone)
   return a.jump.col(zone.tc + zone:borderThickness()) .. a.jump.down(1)
end

local lines = import("core/string", "lines")

local function _writeLines(write, zone, str)
   local nl = _nl(zone)
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


### \_renderRainbuf

Render the zone contents as a Rainbuf, wrapping them **in** a Rainbuf if needed\.

```lua
local instanceof = import("core/meta", "instanceof")

local function _renderRainbuf(write, zone)
   if not zone.contents then
      return nil
   end
   assert(instanceof(zone.contents, Rainbuf))
   local nl = _nl(zone)
   for line in zone.contents:lineGen(zone:clientHeight(), zone:clientWidth()) do
      write(line)
      write(nl)
   end
end
```

### \_renderTxtbuf\(modeS, zone\)

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

### Zone:paintBorder\(write\)

Paints a border around the Zone using anterm box\-drawing primitives
if zone\.border is true\.

```lua
local box = require "anterm/box"
function Zone.paintBorder(zone, write)
   if zone.border then
      write(box.double(zone.tr, zone.tc, zone.br, zone.bc))
   end
end
```

### Zone:erase\(write\)

```lua
function Zone.erase(zone, write)
   write(a.erase.box(zone.tc, zone.tr, zone.bc, zone.br))
end
```

### Zone:paint\(write\)

```lua
function Zone.paint(zone, write)
   if not (zone.visible and zone.touched) then
      return
   end
   zone:erase(write)
   write(a.jump(zone.tr, zone.tc))
   zone:paintBorder(write)
   write(a.jump(zone.tr + zone:borderThickness(),
                zone.tc + zone:borderThickness()))
   -- actually render ze contents
   if type(zone.contents) == "string" then
      _writeLines(write, zone, zone.contents)
   elseif instanceof(zone.contents, Txtbuf) then
      _renderTxtbuf(modeS, zone, write)
   else
      _renderRainbuf(write, zone)
   end
   zone.touched = false
end
```

## Zoneherd methods

### Zoneherd:addZone\(zone\)

Adds `zone` to the zoneherd, maintaining the zone collection in order
of z\-value\. New zones are placed after any others with the same z\-value\.

```lua
local insert = assert(table.insert)

function Zoneherd.addZone(zoneherd, zone)
   zoneherd[zone.name] = zone
   zone.zoneherd = zoneherd
   local insert_index
   for i, existing in ipairs(zoneherd) do
      if existing.z > zone.z then
         insert_index = i
         break
      end
   end
   if insert_index then
      insert(zoneherd, insert_index, zone)
   else
      insert(zoneherd, zone)
   end
   return zoneherd
end
```

### Zoneherd:newZone\(name, z, debug\_mark\)

Creates a new zone and adds it to the Zoneherd\. Note that we don't
set the zone's position and dimensions here, as we expect that to be
determined as part of reflow\.

```lua
local function newZone(name, z, debug_mark)
   local zone = meta(Zone)
   zone.name = name
   zone.debug_mark = debug_mark
   zone.z = z
   zone.visible = true
   zone.touched = false
   -- zone.contents, aspirationally a rainbuf, is provided later
   return zone
end

function Zoneherd.newZone(zoneherd, name, z, debug_mark)
   return zoneherd:addZone(newZone(name, z, debug_mark))
end
```

#### \_zoneOffset\(modes\)

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

### Zoneherd:reflow\(modeS\)

```lua
local ceil, floor = assert(math.ceil), assert(math.floor)

function Zoneherd.reflow(zoneherd, modeS)
   local right_col = modeS.max_col - _zoneOffset(modeS)
   local txt_off = modeS:continuationLines()
   zoneherd.status:setBounds(  1, 1, right_col, 1)
   zoneherd.stat_col:setBounds(right_col + 1, 1,
                               modeS.max_col, 1 )
   zoneherd.prompt:setBounds(  1,
                               modeS.repl_top,
                               modeS.l_margin - 1,
                               modeS.repl_top + txt_off )
   zoneherd.command:setBounds( modeS.l_margin,
                               modeS.repl_top,
                               right_col,
                               modeS.repl_top + txt_off )
   zoneherd.results:setBounds( 1,
                               modeS.repl_top + txt_off + 1,
                               right_col,
                               modeS.max_row )
   zoneherd.suggest:setBounds( right_col + 1,
                               modeS.repl_top + 1,
                               modeS.max_col,
                               modeS.max_row )
   -- Popup is centered and 2/3 of max width, i.e. from 1/6 to 5/6
   zoneherd.popup:setBounds(   floor(modeS.max_col / 6),
                               modeS.repl_top + txt_off + 1,
                               ceil(modeS.max_col * 5 / 6),
                               modeS.max_row)
   return zoneherd
end
```


### Zoneherd:paint\(modeS\)

Once again we pass a reference to the `modeselektor` to get access to things
like the lexer\.

```lua

function Zoneherd.paint(zoneherd, modeS)
   local write = zoneherd.write
   write(a.cursor.hide(), a.clear())
   for i, zone in ipairs(zoneherd) do
      zone:paint(write)
   end
   modeS:placeCursor()
   write(a.cursor.show())
   return zoneherd
end
```

### new

Makes a Zoneherd\.  Borrows the modeselektor to get proportions, but returns
the zoneherd, which is assigned to its slot on the modeselector at the call
site, for consistency\.

```lua
local function new(modeS, writer)
   local zoneherd = meta(Zoneherd)
   zoneherd.write = writer
   -- make Zones
   -- correct values are provided by reflow
   zoneherd:newZone("status", 1, ".")
   zoneherd:newZone("stat_col", 1, "!")
   zoneherd:newZone("prompt", 1, ">")
   zoneherd:newZone("command", 1, "$")
   zoneherd:newZone("results", 1, "~")
   zoneherd:newZone("suggest", 1, "%")
   zoneherd:newZone("popup", 2, "^")
   zoneherd.popup.visible = false
   zoneherd.popup.border = true
   zoneherd:reflow(modeS)

   return zoneherd
end
```

```lua
return new
```
