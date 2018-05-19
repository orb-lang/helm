# Modeselektor

``femto`` will hold all state for an terminal session.  Soon, we will
encapsulate that, making the library re-entrant.


``modeselektor`` is the modal interpreter for the repl language, which becomes
the core of ``ed``.  This is a glorified lookup table with a state switch and
a pointer to the ``femto``cell we're operating on.


## Design

  ``femto`` passes keystrokes as messages to ``modeselektor``.  It does no writes
to stdout at all.  It is smart enough to categorize and parse various device
reports, but has no knowledge of why those reports were requested.


``femto`` runs the event loop, so all other members are pulled in as modules.


``modeselektor`` takes care of system-level housekeeping: opening files
and sockets, keeping command history, fuzzy completion, and has its own eval
loop off the main track.  For evaluating lines, it will call a small executor,
so that in a little while we can put the user program in its own ``LuaL_state``.


This is both good practice, and absolutely necessary if we are to REPL other
``bridge`` programs, each of which has its own event loop.


The implementation is essentially a VM.  Category and value are
successively looked up in jump tables and the method applied with the ``modeS``
instance as the first argument.


``modeselektor`` passes any edit or movement commands to an internally-owned
``linebuf``, which keeps all modeling of the line.  ``modeselektor`` decides when
to repaint the screen, calling ``rainbuf`` with a region of ``linebuf`` and
instructions as to how to paint it.


There is one ``deck`` instance member per screen, which tiles the available
space.  ``modeselektor`` is the writer, and ``rainbuf`` holds a pointer to the
table for read access.


When we have our fancy parse engine and quipu structure, linebuf will call
``comb`` to redecorate the syntax tree before passing it to ``rainbuf`` for
markup.  At the moment I'm just going to write some crude lexers, which
will be more than enough for Clu and Lua, which have straightforward syntax.


An intermediate step could just squeeze the linebuf into a string, parse it
with ``esplalier`` and emit a ``rainbuf`` through the usual recursive method
lookup.  The problem isn't speed, not for a REPL, it's not having error
recovery parsing available.


I will likely content myself with a grammar that kicks in when the user
presses return.  I'll want that to perform rewrites (such as removing
outer-level ``local``s to facilicate copy-pasting) and keep the readline
grammar from becoming too ad-hoc.


#### asserts

  There is little sense running ``modeselektor`` outside of the ``bridge``
environment.

```lua
assert(meta, "must have meta in _G")
assert(write, "must have write in _G")
assert(ts, "must have ts in _G")
```
#### includes

The easiest way to go mad in concurrent environments is to share memory.


``modeselektor`` will own linebuf, and eventually txtbuf, unless I come up with
a better idea.


``rainbuf`` should be built inside ``femto`` and passed in as an argument.

```lua
local Linebuf = require "linebuf"
```
```lua
local ModeS = meta()
```
### Categories

These are the types of event recognized by ``femto``.

```lua
local INSERT = meta()
local NAV    = {}
local CTRL   = {}
local ALT    = {}
local FN     = {}
local MOUSE  = {}
```

Color schemes are supposed to be one-and-done, and I strongly suspect we
have a ``__concat`` dominated workflow, although I have yet to turn on the
profiler.


Therefore we use reference equality for the ``color`` and ``hints`` tables.
Switching themes is a matter of repopulating those tables.  I intend to
isolate this within an instance so that multiple terminals can each run their
own theme, through a simple 'fat inheritance' method.


``modeselektor`` is what you might call hypermodal. Everything is isolated in
its own lookup, that is, we use _value_ equality.  This lets us pass strings
as messages and use jump tables to resolve most things.


It typically runs at the speed of human fingers and can afford to be much less
efficient than it will be, even before the JIT gets involved.


Note also that everything is a method, our dispatch pattern will always
include the ``modeS`` instance as the first argument.

```lua
ModeS.modes = { INSERT = INSERT,
                NAV    = NAV,
                CTRL   = CTRL,
                ALT    = ALT,
                MOUSE  = MOUSE,
                NYI    = true }
```

Sometimes its useful to briefly override handlers, so we check values
against ``special`` first:

```lua
ModeS.special = {}
```

A simple pass-through so we can see what we're missing.

```lua
function ModeS.default(modeS, category, value)
    return write(ts(value))
end
```
### self-insert(modeS, category, value)

Inserts the value into the linebuf at cursor.

```lua
local function self_insert(modeS, category, value)
    local success =  modeS.linebuf:insert(value)
    if not success then
      write("no insert: " .. value)
    else
      write(value)
    end
end
```
### status painter (colwrite)

Time to port over the repl feedback code from femto.

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

function pr_mouse(m)
   local phrase = a.magenta(m.button) .. ": "
                     .. a.bright(kind) .. " " .. ts(m.shift)
                     .. " " .. ts(m.meta)
                     .. " " .. ts(m.ctrl) .. " " .. ts(m.moving) .. " "
                     .. ts(m.scrolling) .. " "
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
                  INSERT = mk_paint(": ", c.field),
                  NYI    = mk_paint(": ", a.red)}

local icon_map = { MOUSE = mk_paint(STAT_ICON, c.userdata),
                   NAV   = mk_paint(STAT_ICON, a.magenta),
                   CTRL  = mk_paint(STAT_ICON, a.blue),
                   ALT   = mk_paint(STAT_ICON, c["function"]),
                   INSERT = mk_paint(STAT_ICON, a.green),
                   NYI   = mk_paint(STAT_ICON .. "! ", a.red) }

local function icon_paint(category, value)
   assert(icon_map[category], "icon_paint NYI:" .. category)
   if category == "MOUSE" then
      return colwrite(icon_map[category]("", pr_mouse(value)))
    end
   return colwrite(icon_map[category]("", ts(value)))
end
```
## act

``act`` simply dispatches. Note that our common interfaces is
``method(modeS, category, value)``, we need to distinguish betwen the tuple
``("INSERT", "SHIFT-LEFT")`` (which could arrive from copy-paste) and
``("NAV", "SHIFT-LEFT")`` and preserve information for our fall-through method.


``act`` always succeeds, meaning we need some metatable action to absorb and
log anything unexpected.

```lua

function repaint(modeS)
  write(a.col(modeS.l_margin))
  write(a.erase.right())
  write(tostring(modeS.linebuf))
  write(a.col(modeS:cur_col()))
end

function ModeS.cur_col(modeS)
   return modeS.linebuf.cursor + modeS.l_margin - 1
end

function ModeS.act(modeS, category, value)
  assert(modeS.modes[category], "no category " .. category .. " in modeS")
   if modeS.special[value] then
      return modeS.special[value](modeS, category, value)
   elseif modeS.modes[category] then
      icon_paint(category, value)
      if category == "INSERT" then
         -- hard coded for now
         self_insert(modeS, category, value)
         repaint(modeS)
      elseif category == "NAV" then
        if value == "RETURN" then
          write(a.col() .. a.jump.down(1)
                .. tostring(modeS.linebuf) .. a.col() .. a.jump.down(1))
        elseif value == "LEFT" then
          modeS.linebuf:left()
          write(a.col(modeS:cur_col()))
          colwrite(ts(move),nil,3)
        elseif value == "RIGHT" then
          modeS.linebuf:right()
          write(a.col(modeS:cur_col()))
          colwrite(ts(move),nil,3)
        end -- etc, jump table
      end
   else
      icon_paint(category, value)
      --colwrite("!! " .. category .. " " .. value, 1, 2)
      return modeS:default(category, value)
   end
end
```

We include indirection in ``act`` itself, looking it up on each call:

```lua
function ModeS.__call(modeS, category, value)
  return modeS:act(category, value)
end
```

This will need to take a complete config table at some point.

```lua
function new()
  local modeS = meta(ModeS)
  modeS.linebuf = Linebuf(1)
  -- this will be more complex but
  modeS.l_margin = 4
  modeS.r_margin = 83
  return modeS
end

ModeS.idEst = new
```
```lua
return new
```
