# Modeselektor

``femto`` will hold all state for an terminal session, including setup of io,
the main event loop, teardown and exuent.  Soon, we will encapsulate that,
making the library re-entrant.


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


The state machine has to represent two sorts of state: the mode we're
operating in, and a buffer of commands.  Our mode engine is modeled after
emacs: rather than have some kind of flag that can be set to "insert",
"navigate", "command", or "visual", these will be modeled as swiching the
pointer to jump tables.  If a command needs to know which mode it's in, this
can be done with pointer comparison.


We're starting with ``vi`` mode and ``nerf`` mode, which is a lightweight
``readline`` implementation that won't use the command buffer.  Issuing a
command like ``d3w`` requires a simple command buffer.


The syntax can't be tied to the semantics in any tighly-coupled way. I intend
to support ``kakoune`` syntax as soon as possible; there you would say ``w3d``.


This implies that the commands can't be aware of the buffer; because ``d3w``
and ``w3d`` are two ways of saying the same thing, they should end in an
identical method call.


This means when the time comes we handle it with a secondary dispatch layer.


There really are effectively arbitrary levels of indirection possible in an
editor.  This is why we must be absolutely consistent about everything
receiving the same tuple (modeS, category, value).


They must also have the same return type, with is either ``true`` or
``false, err``  where ``err`` is an error object which may be a primitive string.


``modeselektor`` passes any edit or movement commands to an internally-owned
``txtbuf``, which keeps all modeling of the line.  ``modeselektor`` decides when
to repaint the screen, calling ``rainbuf`` with a region of ``txtbuf`` and
instructions as to how to paint it.


There is one ``deck`` instance member per screen, which tiles the available
space.  ``modeselektor`` is the writer, and ``rainbuf`` holds a pointer to the
table for read access.


When we have our fancy parse engine and quipu structure, txtbuf will call
``comb`` to redecorate the syntax tree before passing it to ``rainbuf`` for
markup.  At the moment I'm just going to write some crude lexers, which
will be more than enough for Clu and Lua, which have straightforward syntax.


An intermediate step could just squeeze the txtbuf into a string, parse it
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


``modeselektor`` will own txtbuf, and eventually txtbuf, unless I come up with
a better idea.

```lua
local Txtbuf   = require "txtbuf"
local Resbuf    = require "resbuf"
local Historian = require "historian"
local Lex       = require "lex"

local concat         = assert(table.concat)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)
```
```lua
local ModeS = meta()
```
### Categories

These are the broad types of event.

```lua
local ASCII  = meta {}
local NAV    = {}
local CTRL   = {}
local ALT    = {}
local FN     = {}
local MOUSE  = {}
local NYI    = {}
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
ModeS.modes = { ASCII  = ASCII,
                NAV    = NAV,
                CTRL   = CTRL,
                ALT    = ALT,
                MOUSE  = MOUSE,
                NYI    = NYI }
```

With some semi-constants:

```lua
ModeS.REPL_LINE = 2
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

Inserts the value into the txtbuf at cursor.

```lua
function ModeS.insert(modeS, category, value)
    local success =  modeS.txtbuf:insert(value)
end
```
### status painter (colwrite)

This is migrating to the paint module

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
   return a.magenta(m.button) .. ": "
      .. a.bright(m.kind) .. " "
      .. tf(m.shift) .. " "
      .. tf(m.meta) .. " "
      .. tf(m.ctrl) .. " "
      .. tf(m.moving) .. " "
      .. tf(m.scrolling) .. " "
      .. a.cyan(m.col) .. "," .. a.cyan(m.row)
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
### ModeS:paint_row()

Does what it says on the label.

```lua
function ModeS.cur_col(modeS)
   return modeS.txtbuf.cursor + modeS.l_margin - 1
end

function ModeS.nl(modeS)
   write(a.col(modeS.l_margin).. a.jump.down(1))
end
```
### ModeS:write(str)

  This will let us phase out the colwrite business in favor of actual tiles in
the terminal.

```lua
function ModeS.write(modeS, str)
   local nl = a.col(modeS.l_margin) .. a.jump.down(1)
   local phrase, num_subs
   phrase, num_subs = gsub(str, "\n", nl)
   write(a.cursor.hide())
   write(phrase)
   write(a.cursor.show())
end
```
```lua
function ModeS.paint_row(modeS)
   local lb = Lex.lua_thor(tostring(modeS.txtbuf))
   write(a.cursor.hide())
   write(a.erase.box(modeS.repl_top, modeS.l_margin,
                     modeS:replLine(), modeS.r_margin))
   write(a.jump(modeS.repl_top, modeS.l_margin))
   modeS:write(concat(lb))
   write(a.rc(modeS.txtbuf.cur_row + modeS.repl_top - 1, modeS:cur_col()))
   write(a.cursor.show())
end
```
```lua
function ModeS.replLine(modeS)
   return modeS.repl_top + #modeS.txtbuf.lines - 1
end
```
```lua
function ModeS.printResults(modeS, results, new)
   local rainbuf = {}
   write(a.cursor.hide())
   modeS:clearResults()
   local row = new and modeS.repl_top + 1 or modeS:replLine() + 1
   modeS:write(a.rc(row, modeS.l_margin))
   for i = 1, results.n do
      if results.frozen then
         rainbuf[i] = results[i]
      else
         rainbuf[i] = ts(results[i])
      end
   end
   modeS:write(concat(rainbuf, '   '))
   write(a.cursor.show())
end
```
```lua
function ModeS.prompt(modeS)
   write(a.jump(modeS.repl_top, 1) .. "👉 ")
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
local assertfmt = assert(core.assertfmt)

function ModeS.act(modeS, category, value)
   assertfmt(modeS.modes[category], "no category %s in modeS", category)
   -- catch special handlers first
   if modeS.special[value] then
      return modeS.special[value](modeS, category, value)
   end
   icon_paint(category, value)

   -- Dispatch on value if possible
   if modeS.modes[category][value] then
      modeS.modes[category][value](modeS, category, value)

   -- otherwise fall back:
   elseif category == "ASCII" then
      -- hard coded for now
      modeS:insert(category, value)
   elseif category == "NAV" then
      if modeS.modes.NAV[value] then
         modeS.modes.NAV[value](modeS, category, value)
      else
         icon_paint("NYI", "NAV::" .. value)
      end
   elseif category == "MOUSE" then
      colwrite(pr_mouse(value), STATCOL, STAT_RUN)
   else
      icon_paint("NYI", category .. ":" .. value)
   end
   return modeS:paint_row()
end
```

To keep ``act`` itself replaceable, we look it up on each call:

```lua
function ModeS.__call(modeS, category, value)
  return modeS:act(category, value)
end
```
### ASCII

Any printable 7 bit utf-8 sequence.


Currently just self-inserts, but watch this space...


### NAV

```lua
local up1, down1 = a.jump.up(), a.jump.down()

function NAV.UP(modeS, category, value)
   local inline = modeS.txtbuf:up()
   if not inline then
      local prev_result, linestash
      if tostring(modeS.txtbuf) ~= ""
         and modeS.hist.cursor > #modeS.hist then
         linestash = modeS.txtbuf
      end
      modeS.txtbuf, prev_result = modeS.hist:prev()
      if linestash then
         modeS.hist:append(linestash)
      end
      modeS:clearResults()
      if prev_result then
         modeS:printResults(prev_result)
      end
   else
      write(up1)
   end
   return modeS
end

function NAV.DOWN(modeS, category, value)
   local inline = modeS.txtbuf:down()
   if not inline then
      local next_p, next_result
      modeS.txtbuf, next_result, next_p = modeS.hist:next()
      if next_p then
         modeS.txtbuf = Txtbuf()
      end
      modeS:clearResults()
      if next_result then
         modeS:printResults(next_result)
      end
   else
      write(down1)
   end
   return modeS
end

function NAV.LEFT(modeS, category, value)
   return modeS.txtbuf:left()
end

function NAV.RIGHT(modeS, category, value)
   return modeS.txtbuf:right()
end

function NAV.RETURN(modeS, category, value)
   -- eval or split line
   local eval = modeS.txtbuf:nl()
   if eval then
     modeS:nl()
     local more = modeS:eval()
     if not more then
       modeS.txtbuf = Txtbuf()
     end
     modeS.hist.cursor = modeS.hist.cursor + 1
   end
end

function NAV.BACKSPACE(modeS, category, value)
   local shrunk =  modeS.txtbuf:d_back()
   if shrunk then
      write(a.stash())
      write(a.rc(modeS:replLine() + 1, 1))
      write(a.erase.line())
      write(a.pop())
   end
end

function NAV.DELETE(modeS, category, value)
   return modeS.txtbuf:d_fwd()
end
```
### CTRL

Many/most of these will be re-used as e.g. "^" and "$" in vim mode.


Thus we will declare them as bare functions and assign them to slots.

```lua
local function cursor_begin(modeS, category, value)
   modeS.txtbuf.cursor = 1
end

CTRL["^A"] = cursor_begin

local function cursor_end(modeS, category, value)
   modeS.txtbuf.cursor = #modeS.txtbuf.lines[modeS.txtbuf.cur_row] + 1
end

CTRL["^E"] = cursor_end
```
### ModeS:eval()


```lua
local function gatherResults(success, ...)
  local n = select('#', ...)
  return success, { n = n, ... }
end
```
```lua
function ModeS.clearResults(modeS)
   write(a.erase.box(modeS.repl_top + 1, 1, modeS.max_row, modeS.r_margin))
end
```
```lua
function ModeS.eval(modeS)
   local chunk = tostring(modeS.txtbuf)

   local success, results
   -- first we prefix return
   local f, err = loadstring('return ' .. chunk, 'REPL')

   if not f then
      -- try again without return
      f, err = loadstring(chunk, 'REPL')
   end
   if not f then
      local head = sub(chunk, 1, 1)
      if head == "=" then -- take pity on old-school Lua hackers
         f, err = loadstring('return ' .. sub(chunk,2), 'REPL')
      end -- more special REPL prefix soon: /, ?, >(?)
   end
   if f then
      success, results = gatherResults(xpcall(f, debug.traceback))
      if success then
      -- successful call
         if results.n > 0 then
            modeS:printResults(results)
         else
            modeS:clearResults()
         end
      else
      -- error
         write(a.cursor.hide())
         modeS:clearResults()
         modeS:write(results[1])
      end
   else
      if err:match "'<eof>'$" then
         -- Lua expects some more input, advance the txtbuf
         modeS.txtbuf:advance()
         write(a.col(1) .. "...")
         return true
      else
         modeS:clearResults()
         modeS:write(err)
         -- pass through to default.
      end
   end

   modeS.hist:append(modeS.txtbuf, results, success)
   modeS.hist.cursor = #modeS.hist
   if success then modeS.hist.results[modeS.txtbuf] = results end
   modeS:prompt()
end
```
## new

This should be configurable via ``cfg``.

```lua
function new(cfg)
  local modeS = meta(ModeS)
  modeS.txtbuf = Txtbuf()
  modeS.hist  = Historian()
  modeS.hist.cursor = #modeS.hist + 1
  -- this will be more complex but
  modeS.l_margin = 4
  modeS.r_margin = 80
  modeS.row = 2
  modeS.repl_top  = ModeS.REPL_LINE
  return modeS
end

ModeS.idEst = new
```
```lua
return new
```
