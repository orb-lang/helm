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
local Valiant = require "valiant:valiant"

local Txtbuf     = require "helm:buf/txtbuf"
local Resbuf     = require "helm:buf/resbuf"
local Historian  = require "helm:historian"
local Lex        = require "helm:lex"
local Zoneherd   = require "helm:zone"
local Maestro    = require "helm:maestro"
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
   return #modeS.maestro.agents.edit - 1
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
   -- #todo Txtbuf should probably be directly aware that a lexer change
   -- requires a re-render
   modeS.txtbuf:beTouched()
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
local function _check_shift(modeS)
   if modeS.shift_to then
      modeS:shiftMode(modeS.shift_to)
      modeS.shift_to = nil
   end
end

function ModeS.actOnce(modeS, event, old_cat_val)
   -- Try to dispatch the new-style event via keymap
   local command, args = modeS.maestro:translate(event)
   if command then
      modeS.maestro:dispatch(event, command, args)
   elseif old_cat_val then
      -- Okay, didn't find anything there, fall back to the old way
      local handled = modeS.raga(modeS, unpack(old_cat_val))
      if handled then
         command = 'LEGACY'
      end
   end
   _check_shift(modeS)
   if modeS.maestro.agents.edit.contents_changed then
      modeS.raga.onTxtbufChanged(modeS)
    -- Treat contents_changed as implying cursor_changed
    -- only ever fire one of the two events
   elseif modeS.maestro.agents.edit.cursor_changed then
      modeS.raga.onCursorChanged(modeS)
   end
   modeS.maestro.agents.edit.contents_changed = false
   modeS.maestro.agents.edit.cursor_changed = false
   -- Check shift_to again in case one of the cursor handlers set it
   _check_shift(modeS)
   return command
end
```

```lua
function ModeS.act(modeS, event, old_cat_val)
   local command
   repeat
      modeS.action_complete = true
      -- The raga may set action_complete to false to cause the command
      -- to be re-processed, most likely after a mode-switch
      local commandThisTime = modeS:actOnce(event, old_cat_val)
      command = command or commandThisTime
   until modeS.action_complete == true
   if not command then
      command = 'NYI'
   end
   -- Inform the input-echo agent of what just happened
   modeS.maestro.agents.input_echo:update(event, command)
   -- Update the prompt--obsolete once this is handled by a Window
   modeS:updatePrompt()
   -- Reflow in case command height has changed. Includes a paint.
   -- Don't allow errors encountered here to break this entire
   -- event-loop iteration, otherwise we become unable to quit if
   -- there's a paint error.
   local success, err = xpcall(modeS.reflow, debug.traceback, modeS)
   if not success then
      io.stderr:write(err, "\n")
      io.stderr:flush()
   end
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


### ModeS:setResults\(results\), :clearResults\(\)

Sets the current "results" to `results`\.

\#todo
awkward right now, as migration to new keymaps proceeds it'll get easier\.

```lua
function ModeS.setResults(modeS, results)
   modeS.maestro.agents.results:update(results)
   return modeS
end

function ModeS.clearResults(modeS)
   return modeS:setResults(nil)
end
```


### ModeS:setStatusLine\(status\_name, format\_args\.\.\.\)

Sets the status line at the top of the screen by updating the StatusAgent\.

\#todo

```lua

function ModeS.setStatusLine(modeS, status_name, ...)
   modeS.maestro.agents.status:update(status_name, ...)
end
```


### ModeS:eval\(\)

```lua
local eval = Valiant(_G, __G)
```

```lua
local insert = assert(table.insert)
local keys = assert(core.keys)

function ModeS.eval(modeS)
   -- Getting ready to eval, cancel any active autocompletion
   modeS.maestro.agents.suggest:cancel()
   local line = modeS.maestro.agents.edit:contents()
   local success, results = eval(line)
   if not success and results == 'advance' then
      modeS.maestro.agents.edit:endOfText()
      modeS.maestro.agents.edit:nl()
   else
      modeS.hist:append(line, results, success)
      modeS.hist.cursor = modeS.hist.n + 1
      modeS:setResults(results)
      modeS.maestro.agents.edit:clear()
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
      -- Discard the second return value from :index
      -- or it will confuse the Txtbuf constructor rather badly
      local line = modeS.hist:index(i)
      modeS.maestro.agents.edit:update(line)
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
   local session = modeS.hist.session
   if session.mode == "macro" and #session > 0 then
      session:save()
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
   modeS :clearResults() :paint()
   -- perform rerun
   -- Replace results:
   local hist = modeS.hist
   local top = hist.n
   hist.n = hist.cursor_start - 1
   -- put instrumented require in restart mode
   eval:restart()
   hist.stmts.savepoint_restart_session()
   for i = hist.cursor_start, top do
      local success, results = eval(tostring(hist[i]))
      assert(results ~= "advance", "Incomplete line when restarting session")
      hist:append(hist[i], results, success, modeS.session)
   end
   eval:reset()
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
  -- #todo this should be a more generic buffer--maybe a Txtbuf, actually,
  -- or a slightly-smarter Stringbuf
   local rb = Resbuf({ ("abcde "):rep(1000), n = 1 }, { scrollable = true })
   modeS.zones.popup:replace(rb)
   modeS.shift_to = "page"
end
```

### ModeS:showModal\(text, button\_style\)

Shows a modal dialog with the given text and button stylesee [](@agent/modal) for valid button styles\)\.

\(
\#todo
which point we won't need this method\.

```lua
function ModeS.showModal(modeS, text, button_style)
   modeS.maestro.agents.modal:update(text, button_style)
   modeS.shift_to = "modal"
   return modeS
end
```

### ModeS:modalAnswer\(\)

\#todo
agent, but it'd be nice to be able to show a modal that way too, first\.

```lua
function ModeS.modalAnswer(modeS)
   return modeS.maestro.agents.modal:answer()
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

   -- Create Actors and other major sub-components
   modeS.hist  = Historian(db)
   modeS.status = setmetatable({}, _stat_M)
   rawset(__G, "stat", modeS.status)
   modeS.max_extent = max_extent
   modeS.write = writer
   modeS.repl_top = ModeS.REPL_LINE
   modeS.zones = Zoneherd(modeS, writer)
   modeS.maestro = Maestro(modeS)
   -- #todo a few people still need this convenience access, grab a ref
   modeS.txtbuf = modeS.zones.command.contents
   -- If we are loading an existing session, start in review mode
   local session = modeS.hist.session
   -- #todo ugh this is clearly the wrong place/way to do this
   modeS.maestro.agents.session:update(session)
   if session.session_id then
      modeS.raga_default = "review"
      -- #todo we should probably do this in raga/review.onShift, but...
      modeS:setStatusLine("review", session.session_title)
   elseif session.session_title then
      -- ...only if we can move this too, and it's less clear where it
      -- should go--raga/nerf.onShift is a possibility, but doesn't feel
      -- like a very good one?
      modeS:setStatusLine(
         session.mode == "macro" and "macro" or "new_session",
         session.session_title)
   else
      modeS:setStatusLine("default")
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























