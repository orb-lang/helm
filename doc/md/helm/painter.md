# Painter


The ``modeselektor`` module responsible for display.


``helm`` is currently both the loop loader and the inbox, and I will eventually
break the latter out into its own module.  In any case, it wholly owns
``stdin``, ``modeselektor`` runs entirely on messages.


``painter`` receives a ``rainbuf`` and a ``region``.  ``modeselektor`` triggers the
creation of ``rainbuf``s and ``region``s; the former is write-owned by
``modeselektor``, the latter write-owned by ``painter``.


First thing we're going to do with ``painter`` is encapsulate all existing use
of ``stdout``.

```lua
assert(meta)
assert(type)
```
```lua
local Paint = meta {}
```

Carryovers from ``modeselektor``, many from ``helm`` originally.


This is the final resting place.

```lua
local STATCOL = 81
local STAT_TOP = 1
local STAT_RUN = 2

local function colwrite(str, col, row)
   col = col or STATCOL
   row = row or STAT_TOP
   local dash = a.stash()
             .. a.cursor.hide()
             .. a.jump(row, col)
             .. a.erase.right()
             .. str
             .. a.pop()
             .. a.cursor.show()
   write(dash)
end

local STAT_ICON = "◉ "

local function tf(bool)
   if bool then
      return ts("t", "true")
   else
      return ts("f", "false")
   end
end

local function pr_mouse(m)
   local phrase = a.magenta(m.button) .. ": "
                     .. a.bright(m.kind) .. " " .. tf(m.shift)
                     .. " " .. tf(m.meta)
                     .. " " .. tf(m.ctrl) .. " " .. tf(m.moving) .. " "
                     .. tf(m.scrolling) .. " "
                     .. a.cyan(m.col) .. "," .. a.cyan(m.row)
   return phrase
end

local function mk_paint(fragment, shade)
   return function(category, action)
      return shade(category .. fragment .. action)
   end
end

local act_map = { MOUSE  = pr_mouse,
                  NAV    = mk_paint(": ", a.italic),
                  CTRL   = mk_paint(": ", c.field),
                  ALT    = mk_paint(": ", a.underscore),
                  ASCII  = mk_paint(": ", c.table),
                  NYI    = mk_paint(": ", a.red)}

local icon_map = { MOUSE = mk_paint(STAT_ICON, c.userdata),
                   NAV   = mk_paint(STAT_ICON, a.magenta),
                   CTRL  = mk_paint(STAT_ICON, a.blue),
                   ALT   = mk_paint(STAT_ICON, c["function"]),
                   ASCII = mk_paint(STAT_ICON, a.green),
                   NYI   = mk_paint(STAT_ICON .. "! ", a.red) }

local function icon_paint(category, value)
   assert(icon_map[category], "icon_paint NYI:" .. category)
   if category == "MOUSE" then
      return colwrite(icon_map[category]("", pr_mouse(value)))
    end
   return colwrite(icon_map[category]("", ts(value)))
end
```
## Paint:inBox(rainbuf, box)

Paints inside a bounding box.  Will paint a mere string, albeit making
incorrect assumptions about width in the presence of escape codes or wchars.


Intended for a rainbuf, where it will exhibit intelligence appropriate to the
occasion.


Supporting a box as an indexed array for now, we can detect keys vs. indices
if the former turns out to be cleaner.  Indexes give a cleaner literal syntax,
which helps for now.

```lua
function Paint.inBox(painter, rainbuf, box)
   local tc, tr, bc, br = box[1], box[2], box[3], box[4]
   if type(rainbuf) == "string" then
      -- string painter
   elseif type(rainbuf) == "table" then
      -- Detect rainbuf.idEst, paint the rainbuf
   end
end
```
```lua
local function new(_stdout)
   local painter = meta(Paint)
   painter.out  = _stdout
   return painter
end
```
```lua
return new
```
