# Modeselektor

`helm` will hold all state for an terminal session, including setup of io,
the main event loop, teardown and exuent\.  Soon, we will encapsulate that,
making the library re\-entrant\.

`modeselektor` is the modal interpreter for the repl language, which becomes
the core of `ed`\.  This is a glorified lookup table with a state switch and
a pointer to the `helm`cell we're operating on\.


## Design

  `helm` passes keystrokes as messages to `modeselektor`\.  It does no writes
to stdout at all\.  It is smart enough to categorize and parse various device
reports, but has no knowledge of why those reports were requested\.

`helm` runs the event loop, so all other members are pulled in as modules\.

`modeselektor` takes care of system\-level housekeeping: opening files
and sockets, keeping command history, fuzzy completion, and has its own eval
loop off the main track\.  For evaluating lines, it will call a small executor,
so that in a little while we can put the user program in its own `LuaL_state`\.

This is both good practice, and absolutely necessary if we are to REPL other
`bridge` programs, each of which has its own event loop\.

The implementation is essentially a VM\.  Category and value are
successively looked up in jump tables and the method applied with the `modeS`
instance as the first argument\.

The state machine has to represent two sorts of state: the mode we're
operating in, and a buffer of commands\.  Our mode engine is modeled after
emacs: rather than have some kind of flag that can be set to "insert",
"navigate", "command", or "visual", these will be modeled as swiching the
pointer to jump tables\.  If a command needs to know which mode it's in, this
can be done with pointer comparison\.

We're starting with `vi` mode and `nerf` mode, which is a lightweight
`readline` implementation that won't use the command buffer\.  Issuing a
command like `d3w` requires a simple command buffer\.

The syntax can't be tied to the semantics in any tighly\-coupled way\. I intend
to support `kakoune` syntax as soon as possible; there you would say `w3d`\.

This implies that the commands can't be aware of the buffer; because `d3w`
and `w3d` are two ways of saying the same thing, they should end in an
identical method call\.

This means when the time comes we handle it with a secondary dispatch layer\.

There really are effectively arbitrary levels of indirection possible in an
editor\.  This is why we must be absolutely consistent about everything
receiving the same tuple \(modeS, category, value\)\.

They must also have the same return type, with is either `true` or
`false, err`  where `err` is an error object which may be a primitive string\.

`modeselektor` passes any edit or movement commands to an internally\-owned
`txtbuf`, which keeps all modeling of the line\.  `modeselektor` decides when
to repaint the screen, calling `rainbuf` \(currently just `lex`\) with a region
of `txtbuf` and instructions as to how to paint it\.

There is one `deck` instance member per screen, which tiles the available
space\.  `modeselektor` is the writer, and `rainbuf` holds a pointer to the
table for read access\.

When we have our fancy parse engine and quipu structure, txtbuf will call
`comb` to redecorate the syntax tree before passing it to `rainbuf` for
markup\.  At the moment I'm just going to write some crude lexers, which
will be more than enough for Clu and Lua, which have straightforward syntax\.

An intermediate step could just squeeze the txtbuf into a string, parse it
with `espalier` and emit a `rainbuf` through the usual recursive method
lookup\.  The problem isn't speed, not for a REPL, it's not having error
recovery parsing available\.

I will likely content myself with a grammar that kicks in when the user
presses return\.  I'll want that to perform rewrites \(such as removing
outer\-level `local`s to facilicate copy\-pasting\) and keep the readline
grammar from becoming too ad\-hoc\.


#### asserts

  There is little sense running `modeselektor` outside of the `bridge`
environment\.

```lua
assert(meta, "must have meta in _G")
```


#### includes

The easiest way to go mad in concurrent environments is to share memory\.

`modeselektor` will own txtbuf, historian, and the entire screen\.

```lua
local Set = require "set:set"
local valiant = require "valiant:valiant"

local Txtbuf     = require "helm:txtbuf"
local Resbuf     = require "helm:resbuf"
local Historian  = require "helm:historian"
local Lex        = require "helm:lex"
local Zoneherd   = require "helm:zone"
local Suggest    = require "helm:suggest"
local repr       = require "repr:repr"
local lua_parser = require "helm:lua-parser"

local concat               = assert(table.concat)
local sub, gsub, rep, find = assert(string.sub),
                             assert(string.gsub),
                             assert(string.rep),
                             assert(string.find)

local ts = repr.ts_color

```

```lua
local ModeS = meta()
```



Color schemes are supposed to be one\-and\-done, and I strongly suspect we
have a `__concat` dominated workflow, although I have yet to turn on the
profiler\.

Therefore we use reference equality for the `color` and `hints` tables\.
Switching themes is a matter of repopulating those tables\.  I intend to
isolate this within an instance so that multiple terminals can each run their
own theme, through a simple 'fat inheritance' method\.

`modeselektor` is what you might call hypermodal\. Everything is isolated in
its own lookup, that is, we use *value* equality\.  This lets us pass strings
as messages and use jump tables to resolve most things\.

It typically runs at the speed of human fingers and can afford to be much less
efficient than it will be, even before the JIT gets involved\.

Note also that everything is a method, our dispatch pattern will always
include the `modeS` instance as the first argument\.

With some semi\-constants:

```lua
ModeS.REPL_LINE = 2
ModeS.PROMPT_WIDTH = 3
```

### ModeS:errPrint\(modeS, category, value\)

Debug aide\.

```lua
function ModeS.errPrint(modeS, log_stmt)
   modeS.zones.suggest:replace(log_stmt)
   modeS:paint()
   return modeS
end
```


### status painter \(colwrite\)

This is a grab\-bag with many traces of the bootstrap process\.

It also contains the state\-of\-the\-art renderers\.


#### bootstrappers

A lot of this just paints mouse events, which we aren't using and won't be
able to use until we rigorously keep track of what's printed where\.

Which is painstaking and annoying, but we'll get there\.\.\.

This will continue to exist for awhile\.

```lua
local c = import("singletons:color", "color")

local STAT_ICON = "◉ "

local function tf(bool)
   return bool and c["true"]("t") or c["false"]("f")
end

local function mouse_paint(m)
   return c.userdata(STAT_ICON)
      .. a.magenta(m.button) .. ": "
      .. tf(m.shift) .. " "
      .. tf(m.meta) .. " "
      .. tf(m.ctrl) .. " "
      .. tf(m.moving) .. " "
      .. tf(m.scrolling) .. " "
      .. a.cyan(m.col) .. "," .. a.cyan(m.row)
end

local function mk_paint(fragment, shade)
   return function(action)
      return shade(fragment .. action)
   end
end

local function paste_paint(frag)
   local result
   -- #todo handle escaping of special characters in pasted data
   if #frag < 20 then
      result = "PASTE: " .. frag
   else
      result = ("PASTE(%d): %s..."):format(#frag, frag:sub(1, 17))
   end
   return a.green(STAT_ICON .. result)
end

local icon_map = { MOUSE = mouse_paint,
                   NAV   = mk_paint(STAT_ICON, a.magenta),
                   CTRL  = mk_paint(STAT_ICON, a.blue),
                   ALT   = mk_paint(STAT_ICON, c["function"]),
                   ASCII = mk_paint(STAT_ICON, a.green),
                   UTF8  = mk_paint(STAT_ICON, a.green),
                   PASTE = paste_paint,
                   NYI   = mk_paint(STAT_ICON .. "! ", a.red) }

local function _make_icon(category, value)
   return icon_map[category](value)
end
```

### ModeS:placeCursor\(\)

Places the cursor where it belongs on the screen\.
We delegate determining where this is to the Raga\.

```lua
local Point = require "anterm:point"
function ModeS.placeCursor(modeS)
   local point = modeS.raga.getCursorPosition(modeS)
   if point then
      modeS.write(a.jump(point), a.cursor.show())
   end
   return modeS
end
```

### ModeS:paint\(\)

Paint the screen\. Primarily handled by the same method on the Zoneherd,
but we must also place the cursor\.

```lua
function ModeS.paint(modeS)
   modeS.zones:paint(modeS)
   modeS:placeCursor(modeS)
   return modeS
end
```


### ModeS:reflow\(\)

```lua
function ModeS.reflow(modeS)
   modeS.zones:reflow(modeS)
   modeS:paint()
   return modeS
end
```

### Prompts and modes / ragas

Time to add modes to the `modeselektor`\! Yes, I'm calling it `raga`
and that's a bit precious, but it's an important and heavily\-used concept,
so it's good to have a unique name\.

Right now everything works on the default mode, "nerf":

```lua
ModeS.raga_default = "nerf"
```

We'll need several basic modes and some ways to do overlay, and we need a
single source of truth as to what mode we're in\.

The entrance for that should be a single function, `ModeS:shiftMode(raga)`,
which takes care of all stateful changes to `modeselektor` needed to enter
the mode\.  One thing it will do is set the field `raga` to the parameter\.

As a general rule, we want mode changes to work generically, by changing
the functions attached to `(category, value)` pairs\.

But sometimes we'll want a bit of logic that dispatches on the mode directly,
repainting is a good example of this\.

The next mode we're going to write is `"search"`\.

#### ModeS:continuationLines\(\)

Answers the number of additional lines \(beyond the first\) needed
for the command zone\.

```lua
function ModeS.continuationLines(modeS)
   return modeS.txtbuf and #modeS.txtbuf - 1 or 0
end
```

#### ModeS:updatePrompt\(\)

Updates the prompt with the correct symbol and number of continuation prompts\.

```lua
function ModeS.updatePrompt(modeS)
   local prompt = modeS.raga.prompt_char .. " " .. ("\n..."):rep(modeS:continuationLines())
   modeS.zones.prompt:replace(prompt)
   return modeS
end
```


### ModeS:shiftMode\(raga\)

The `modeselektor`, as described in the prelude, is a stateful and hypermodal
`repl` environment\.

`shiftMode` is the gear stick which drives the state\. It encapsulates the
state changes needed to switch between them\.

I'm going to go ahead and weld on `search` before I start waxing eloquent\.


#### ModeS\.closet

A storage table for modes and other things we aren't using and need to
retrieve\.

```lua
local Nerf      = require "helm:raga/nerf"
local Search    = require "helm:raga/search"
local Complete  = require "helm:raga/complete"
local Page      = require "helm:raga/page"
local Modal     = require "helm:raga/modal"
local Review    = require "helm:raga/review"
local EditTitle = require "helm:raga/edit-title"

ModeS.closet = { nerf =       { raga = Nerf,
                                lex  = Lex.lua_thor },
                 search =     { raga = Search,
                                lex  = Lex.null },
                 complete =   { raga = Complete,
                                lex  = Lex.lua_thor },
                 page =       { raga = Page,
                                lex  = Lex.null },
                 review =     { raga = Review,
                                lex  = Lex.null },
                 edit_title = { raga = EditTitle,
                                lex = Lex.null },
                 modal =      { raga = Modal,
                                lex  = Lex.null } }

function ModeS.shiftMode(modeS, raga_name)
   -- Stash the current lexer associated with the current raga
   -- Currently we never change the lexer separate from the raga,
   -- but this will change when we start supporting multiple languages
   -- Guard against nil raga or lexer during startup
   if modeS.raga then
      modeS.raga.onUnshift(modeS)
      modeS.closet[modeS.raga.name].lex = modeS.txtbuf.lex
   end
   -- Switch in the new raga and associated lexer
   modeS.raga = modeS.closet[raga_name].raga
   modeS.txtbuf.lex = modeS.closet[raga_name].lex
   modeS.raga.onShift(modeS)
   modeS:updatePrompt()
   return modeS
end
```


## act

`act` dispatches a single seq \(which has already been parsed into \(category, value\)
by `onseq`\)\. It may try the dispatch multiple times if the raga indicates
that reprocessing is needed by setting `modeS.action_complete` to =false\.

Note that our common interface is `method(modeS, category, value)`,
we need to distinguish betwen the tuple `("INSERT", "SHIFT-LEFT")`which could arrive from copy\-paste\) and `("NAV", "SHIFT-LEFT")`
and
\( preserve information for our fall\-through method\.

`act` always succeeds, meaning we need some metatable action to absorb and
log anything unexpected\.


### actOnce

Dispatches a seq to the current raga, answering whether or not the raga could
process it \(if this never occurs, we display an NYI message in the status area\)\.

```lua
function ModeS.actOnce(modeS, category, value)
   local handled = modeS.raga(modeS, category, value)
   if modeS.shift_to then
      modeS:shiftMode(modeS.shift_to)
      modeS.shift_to = nil
   end
   if modeS.txtbuf.contents_changed then
      modeS.zones.command:beTouched()
      modeS.raga.onTxtbufChanged(modeS)
      modeS.txtbuf.contents_changed = false
   end
   if modeS.txtbuf.cursor_changed then
      modeS.raga.onCursorChanged(modeS)
      modeS.txtbuf.cursor_changed = false
   end
   return handled
end
```

```lua
function ModeS.act(modeS, category, value)
   local icon = _make_icon(category, value)
   local handled = false
   repeat
      modeS.action_complete = true
      -- The raga may set action_complete to false to cause the command
      -- to be re-processed, most likely after a mode-switch
      local handledThisTime = modeS:actOnce(category, value)
      handled = handled or handledThisTime
   until modeS.action_complete == true
   if not handled then
      local val_rep = string.format("%q",value):sub(2,-2)
      icon = _make_icon("NYI", category .. ": " .. val_rep)
   end

   -- Replace zones
   modeS.zones.stat_col:replace(icon)
   modeS:updatePrompt()
   -- Reflow in case command height has changed. Includes a paint.
   -- Don't allow errors encountered here to break this entire
   -- event-loop iteration, otherwise we become unable to quit if
   -- there's a paint error.
   xpcall(modeS.reflow, function(err)
      io.stderr:write(err, "\n", debug.traceback(), "\n")
      io.stderr:flush()
   end, modeS)
   collectgarbage()
   return modeS
end
```

To keep `act` itself replaceable, we look it up on each call:

```lua
function ModeS.__call(modeS, category, value)
   return modeS:act(category, value)
end
```


### ModeS:setResults\(results\)

Sets the contents of the results area to `results`, wrapping it in a Resbuf
if necessary\. Strings are passed through unchanged\.

```lua
local instanceof = import("core:meta", "instanceof")

function ModeS.setResults(modeS, results)
   results = results or ""
   if results == "" then
      modeS.zones.results:replace(results)
      return modeS
   end
   local cfg = { scrollable = true }
   if type(results) == "string" then
      cfg.frozen = true
      results = { results, n = 1 }
   end
   modeS.zones.results:replace(Resbuf(results, cfg))
   return modeS
end
```


### ModeS:setStatusLine\(status\_name\)

Sets the status line at the top of the screen,
from a list of predefined statuses\.

```lua
ModeS.status_lines = { default = "an repl, plz reply uwu 👀",
                       quit    = "exiting repl, owo... 🐲",
                       restart = "restarting an repl ↩️" }

function ModeS.setStatusLine(modeS, status_name)
   modeS.zones.status:replace(modeS.status_lines[status_name])
   return modeS
end
```


### ModeS:setTxtbuf\(txtbuf\)

Replaces the current Txtbuf with `txtbuf`\. This effectively involves
changes to the cursor and contents, so we set those flags\.

```lua
function ModeS.setTxtbuf(modeS, txtbuf)
   -- Copy the lexer and suggestions over to the new Txtbuf
   -- #todo keep the same Txtbuf around (updating it using :replace())
   -- rather than swapping it out
   txtbuf.lex = modeS.txtbuf.lex
   txtbuf.active_suggestions = modeS.txtbuf.active_suggestions
   modeS.txtbuf = txtbuf
   modeS.txtbuf.cursor_changed = true
   modeS.txtbuf.contents_changed = true
   modeS.zones.command:replace(modeS.txtbuf)
   return modeS
end
```


### ModeS:eval\(\)

```lua
local evaluate, req = assert(valiant(_G, __G))
```

```lua
local insert = assert(table.insert)
local keys = assert(core.keys)

function ModeS.eval(modeS)
   -- Getting ready to eval, cancel any active autocompletion
   modeS.suggest:cancel(modeS)
   local success, results = evaluate(tostring(modeS.txtbuf))
   if not success and results == 'advance' then
      modeS.txtbuf:endOfText()
      modeS.txtbuf:nl()
   else
      modeS.hist:append(modeS.txtbuf, results, success)
      modeS.hist.cursor = modeS.hist.n + 1
      modeS:setResults(results)
      modeS:setTxtbuf(Txtbuf())
   end

   return modeS
end
```


### ModeS:evalFromCursor\(\)

Evaluates every result from the current historian cursor to the top of the
history\.

```lua
function ModeS.evalFromCursor(modeS)
   local top = modeS.hist.n
   local cursor = modeS.hist.cursor
   for i = cursor, top do
      modeS:setTxtbuf(modeS.hist:index(i))
      modeS:eval()
   end
end
```


### ModeS:quit\(\)

Marks the modeselektor as ready to quit \(the actual teardown will happen
in the outer event\-loop code in helm\.orb\)

```lua
function ModeS.quit(modeS)
   -- #todo handle this better--as an event of sorts, maybe?
   if modeS.hist.session.mode == "macro" then
      modeS.hist.session:save()
   end
   modeS:setStatusLine("quit")
   modeS.has_quit = true
end
```


### ModeS:restart\(\)

This resets `_G` and runs all commands in the current session\.

```lua
function ModeS.restart(modeS)
   modeS :setStatusLine 'restart'
   -- remove existing result
   modeS :setResults "" :paint()
   -- perform rerun
   -- Replace results:
   local hist = modeS.hist
   local top = hist.n
   hist.n = hist.cursor_start - 1
   -- put instrumented require in restart mode
   req:restart()
   hist.stmts.savepoint_restart_session()
   for i = hist.cursor_start, top do
      local success, results = evaluate(tostring(hist[i]))
      assert(results ~= "advance", "Incomplete line when restarting session")
      hist:append(hist[i], results, success, modeS.session)
   end
   req:reset()
   assert(hist.n == #hist, "History length mismatch after restart: n = "
         .. tostring(hist.n) .. ", # = " , tostring(#hist))
   modeS :setResults(hist.result_buffer[hist.cursor]) :paint()
   uv.timer_start(uv.new_timer(), 1500, 0,
                  function()
                     modeS :setStatusLine 'default' :paint()
                  end)
   local restart_idle = uv.new_idle()
   restart_idle:start(function()
      if #hist.idlers > 0 then
         return nil
      end
      hist.stmts.release_restart_session()
      restart_idle:stop()
   end)
   return modeS
end
```

### ModeS:openHelp\(\)

Opens a simple help screen\.

```lua
function ModeS.openHelp(modeS)
  -- #todo this should be a generic Rainbuf
   local rb = Resbuf{ ("abcde "):rep(1000), n = 1 }
   modeS.zones.popup:replace(rb)
   modeS.shift_to = "page"
end
```

### ModeS:showModal\(text, button\_style\)

Shows a modal dialog with the given text and button style
\(see raga/modal\.orb for valid button styles\)\.

When the modal closes, the button that was clicked can be retrieved
with modeS:modalAnswer\(\)\.

```lua
function ModeS.showModal(modeS, text, button_style)
   local modal_info = Modal.newModel(text, button_style)
   -- #todo make DialogModel a kind of Rainbuf? Or use a generic one?
   modeS.zones.modal:replace(Resbuf{ modal_info, n = 1 })
   modeS.shift_to = "modal"
   return modeS
end
```

### ModeS:modalAnswer\(\)

Convenience method to retrieve the value answered by the most recent
modal dialog\. Storing this in the contents of the modal zone is
hardly ideal, but it's not clear what the mechanism **should** look like\.

```lua
function ModeS.modalAnswer(modeS)
   local contents = modeS.zones.modal.contents
   return (contents and contents.is_rainbuf) and contents[1].value or nil
end
```

#### modeS\.status

A way to jack into `status`\.

```lua
local function _status__repr(status_table)
   return concat(status_table)
end

local _stat_M = meta {}
_stat_M.__repr = _status__repr

function _stat_M.clear(status_table)
   return setmetatable({}, getmetatable(status_table))
end
```


## new

Start by making a snapshot of \_G and package\.loaded\. We use this for reloading;
since all userspace is stored in \_G, this allows us to drop all data held
in a session, while keeping our own state separate\.

\#NB
in the registry, and uses that for access within `require`, so we must
separately keep track of what packages were loaded so we can nil out any
"extras" when we restart\.

```lua
local deepclone = assert(core.deepclone)
local function new(max_extent, writer, db)
   local modeS = meta(ModeS)

   modeS.txtbuf = Txtbuf()
   modeS.hist  = Historian(db)
   modeS.suggest = Suggest()
   modeS.status = setmetatable({}, _stat_M)
   rawset(__G, "stat", modeS.status)
   modeS.max_extent = max_extent
   modeS.write = writer
   modeS.repl_top = ModeS.REPL_LINE
   modeS.zones = Zoneherd(modeS, writer)
   modeS:setStatusLine("default")
   modeS.zones.command:replace(modeS.txtbuf)
   -- If we are loading an existing session, start in review mode
   if _Bridge.args.session then
      modeS.raga_default = "review"
   end
   -- initial state
   modeS:shiftMode(modeS.raga_default)
   modeS.action_complete = true
   modeS.shift_to = nil
   return modeS
end

ModeS.idEst = new
```

```lua
return new
```























