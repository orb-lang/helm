#  Helm


`helm` is our repl\.


##### profiler

Normally commented out\.

Planning to run this from time to time if it looks like we have significant
performance regressions\.

```lua
--[[
profile = require("jit.profile")
profiled = {}
profile.start("li1", function(th, samples, vmmode)
   local d = profile.dumpstack(th, "pFZ;", 6)
   profiled[d] = (profiled[d] or 0) + samples
end)
--]]
```

```lua
assert(true)
if rawget(_G, "_Bridge") then
   _Bridge.helm = true
end
```


#### Intercept \_G

We don't want to put `helm` into the environment of the codebase under
examination, so we replace the global environment with a table which falls
back to `_G`\. We make it available as a global anywhere in \`helm\`, without
exposing it to others who are still using the normal \_G global environment\.

Man\.  I really like having first\-class environments\.

```lua
local __G = setmetatable({}, {__index = _G})
__G.__G = __G
```

### \_helm

The entire module is setup as a function, to allow our new fenv
to be passed in\.

```lua
local function _helm(_ENV)
```

No sense wasting a level of indent on a wrapper imho

```lua
setfenv(0, __G)

import = assert(require "core/module" . import)
meta = assert(require "core:cluster" . Meta)
core = require "core:core"
kit = require "valiant:replkit"
jit.vmdef = require "helm:helm/vmdef"
jit.p = require "helm:helm/ljprof"
sql = assert(sql, "sql must be in _G")
```


## send\(tab\)

Turns `tab` into a message and `yield` s it\.

We do a lot of message passing in `helm`, and we'll be doing more, so this is
a useful global to have\.

```lua
local yield = assert(coroutine.yield)
local Message = require "actor:message"

function send(tab)
   return yield(Message(tab))
end
```

## Boot sequence

This boot sequence builds on Tim Caswell and the Luvit Author's repl example\.

```lua
uv = require "luv"
local usecolors
stdout = ""
```


##### tty detection

  Should move this into `pylon` as a method in a bridge preload package, or
something like that\.  We're not using the not tty branch, we just bail later
if we're in a pipe\.

```lua
if uv.guess_handle(1) == 'tty' then
   stdout = uv.new_tty(1, false)
   usecolors = true
else
   stdout = uv.new_pipe(false)
   uv.pipe_open(utils.stdout, 1)
   usecolors = false
end
```

Not\-blocking `write` and `print`:

```lua
local function write(...)
   uv.write(stdout, {...})
end
```

```lua
local concat = assert(table.concat)

function print(...)
   local n = select('#', ...)
   local arguments = {...}
   for i = 1, n do
      arguments[i] = tostring(arguments[i])
   end
   uv.write(stdout, concat(arguments, "\t") .. "\n")
end
```


### tty setup

```lua
if uv.guess_handle(0) ~= 'tty' or
   uv.guess_handle(1) ~= 'tty' then
   -- Bail if we're in a pipe
   error "stdio must be a tty"
end

local stdin = uv.new_tty(0, true)
```

Primitives for terminal manipulation\.

```lua
a = require "anterm:anterm"
local Point = require "anterm:point"
```

## Modeselektor


```lua

-- Get window size and set up a SIGWINCH handler to keep it refreshed

local max_col, max_row = stdin:get_winsize()
local max_extent = Point(max_row, max_col)

modeS = require "helm/modeselektor" (max_extent, write)
local insert = assert(table.insert)
local function s_out(msg)
   insert(modeS.status, msg)
end

-- make a new 'status' instance
local s = require "status:status" (s_out)

local function check_winsize()
   max_col, max_row = stdin:get_winsize()
   max_extent = Point(max_row, max_col)
   if max_extent ~= modeS.max_extent then
      modeS.max_extent = max_extent
      -- Mark all zones as touched since we don't know the state of the screen
      -- (some terminals, iTerm for sure, will attempt to reflow the screen
      -- themselves and fail miserably)
      for _, zone in ipairs(modeS.zones) do
         zone.touched = true
      end
      modeS:reflow()
   end
end

local winsize_watch = uv.new_timer()
winsize_watch:start(500, 500, check_winsize)
local winsize_signal = uv.new_signal()
winsize_signal:start("sigwinch", check_winsize)
```


## Reader

The reader takes a stream of data from `stdin`, asynchronously, and
processes it into tokens, which stream to the `modeselektor`\.


### onseq

Our `uv` read handler\. Parses an input sequence into events and dispatches
them to the `Modeselektor`\.

There seems to be a maximum size of sequence that we will be given at once, so
when input arrives extremely rapidly \(the most common case being a large
paste\), it may be chopped off at an arbitrary point\. By default, the input
parser rejects any input that may represent an incomplete escape sequence\. In
this case, we store the remaining input and try again in the next event\-loop
cycle\. If we did not receive any new input in that cycle, we inform the parser
that no more input is expected and it should parse ESC and CSI immediately
rather than holding on to them in case they begin an escape sequence\.

`uv`, being an event loop, seems to sometimes keep reading after we expect it
to stop\. We use a `_ditch` flag to prevents modeS from being reloaded in such
circumstances\.

```lua
local _ditch = false

local parse_input = require "anterm:input-parser"

local should_dispatch_all = false
local input_timer = uv.new_timer()
local input_check = uv.new_check()
local input_buffer = ""

local function is_scroll(event)
   return event.type == "mouse" and event.scrolling
end

local compact = assert(require "core:table" . compact)

local function consolidate_scroll_events(events)
   -- We're going to nil-and-compact, so convert to ntable
   events.n = #events
   local i = 1
   while i <= events.n do
      local j = i + 1
      if is_scroll(events[i]) then
         events[i].num_lines = 1
         while j <= events.n
            and is_scroll(events[j])
            and events[j].key == events[i].key do
            events[i].num_lines = events[i].num_lines + 1
            events[j] = nil
            j = j + 1
         end
      end
      i = j
   end
   compact(events)
end
```


#### shutDown\(modeS\)

Handles shutdown of the `uv` event loop in a hopefully graceful fashion\.

```lua
local Set = require "set:set"

local stoppable = Set { 'idle',
                        'check',
                        'prepare',
                        'timer',
                        'poll',
                        'signal',
                        'fs_event',
                        'fs_poll' }

local function shutDown(modeS)
   _ditch = true
   uv.read_stop(stdin)
   winsize_watch:stop()
   winsize_watch:close()
   winsize_signal:stop()
   winsize_signal:close()
   input_timer:stop()
   input_timer:close()
   input_check:stop()
   input_check:close()
   local idlers = modeS.hist.idlers
   uv.walk(function(handle)
      -- break down anything that isn't a historian idler or our stdio
      if not (idlers(handle) or handle == stdin or handle == stdout) then
         local h_type = uv.handle_get_type(handle)
         if stoppable(h_type) then
            io.stderr:write("Stopping a leftover ", h_type, " ", tostring(handle), "\n")
            handle:stop()
         end
         if not handle:is_closing() then
            io.stderr:write("Closing a leftover ", h_type, " ", tostring(handle), "\n")
            handle:close()
         end
      end
   end)
end
```


#### dispatch\_input\(seq, dispatch\_all\)

Parses `seq` into input events and dispatches them to `modeS`\.

If `dispatch_all` is false, leaves any potentially incomplete or ambiguous
input in the buffer to be retried on the next tick\. This includes trailing
ESC and CSI sequences and unparseable input \(such as a paste event whose
closing sequence has not yet arrived\.\)

If there is incomplete or ambiguous input, we also set a timer to ensure that
it is parsed as soon as no input has arrived for 5ms\.

If `dispatch_all` is true, trailing ESC and CSI are dispatched immediately,
and remaining unparseable input raises an error\.

```lua
local function dispatch_input(seq, dispatch_all)
   -- Clear the flag and timer indicating whether we should clear down the
   -- input buffer this cycle. We explicitly stop the timer in case another
   -- loop iteration occurs before the 5ms delay elapses (e.g. due to an
   -- idler). We must use a timer with a nonzero delay because it seems that
   -- the loop sometimes fails to retrieve input that should logically already
   -- be present (e.g. due to a large paste) unless we wait.
   should_dispatch_all = false
   input_timer:stop()
   -- Try parsing, letting the parser know whether it should definitely consume
   -- everything it can or hold off on possible incomplete escape sequences
   local events, pos = parse_input(seq, dispatch_all)
   input_buffer = seq:sub(pos)
   if #input_buffer > 0 then
      if dispatch_all then
         -- If it's been a little while and we still have stuff we can't parse,
         -- figure we might have something actually invalid.
         -- #todo perform some kind of useful error recovery here
         error("Unparseable input encountered:\n" .. input_buffer)
      else
         -- Use a timer to wait until all available input has arrived to
         -- set the flag that will cause our check handler to clear the
         -- input buffer. If more input is available sooner than the 5ms
         -- timeout, it will be processed immediately and the timer reset.
         -- This is (hopefully) an upper bound on how long it will take the
         -- next chunk of a large paste to arrive.
         input_timer:start(5, 0, function() should_dispatch_all = true end)
      end
   end
   consolidate_scroll_events(events)
   for _, event in ipairs(events) do
      modeS(event)
      -- Okay, if the action resulted in a quit, break out of the event loop
      if modeS.has_quit then
         shutDown(modeS)
         break
      end
   end
end

input_check:start(function()
   if should_dispatch_all and #input_buffer > 0 then
      dispatch_input(input_buffer, true)
   end
end)
```


#### onseq itself

Add a layer of error handling around dispatch\_input so that errors in
event handling can at least crash helm gracefully, restoring the terminal
to a sane state\.

If an error is encountered, we store it so it can be printed after the
terminal state has been restored\.

```lua
local onseq_err

local function onseq(err, seq)
   if _ditch then return nil end
   local success, err_trace = xpcall(function()
      if err then error(err) end
      dispatch_input(input_buffer .. seq, false)
   end, debug.traceback)
   if not success then
      shutDown(modeS)
      onseq_err = err_trace
   end
end
```

```lua


-- Get names for as many values as possible
-- into the colorizer
-- Treat package names as existing in the global namespace
-- rather than having a "package.loaded." prefix
local names = require "repr:repr/names"
names.loadNames(package.loaded)
names.loadNames(_G)
names.loadNames(__G)

-- assuming we survived that, set up our repling environment:

-- raw mode
uv.tty_set_mode(stdin, 2)

-- Enable mouse tracking, save the cursor, switch screens and wipe,
-- then put the cursor at 1,1.
-- #todo Cursor save/restore supposedly may not work on all terminals?
-- Test this and, if necessary, explicitly read and store the cursor position
-- and manually restore it at the end.
write(a.cursor.stash(),
      a.alternate_screen(true),
      a.erase.all(),
      a.jump(1, 1),
      a.paste_bracketing(true),
      a.mouse.track(true),
      a.mouse.sgr_mode(true)
)
uv.read_start(stdin, onseq)

-- initial layout and paint screen
modeS:reflow()

--[[ stop profiler if we're using it to measure startup time
profile.stop()
--]]

-- main loop
uv.run()

-- Teardown: Mouse tracking off, restore main screen and cursor
io.stdout:write(a.mouse.sgr_mode(false),
                a.mouse.track(false),
                a.paste_bracketing(false),
                a.alternate_screen(false),
                a.cursor.pop(),
                a.cursor.show())

-- Back to normal mode
uv.tty_reset_mode()

-- Done with uv TTY handles. Note that closing these does not close
-- the underlying FDs, we still need those.
stdin:close()
stdout:close()

-- Make sure the terminal processes all of the above,
-- then remove any spurious mouse inputs or other stdin stuff
io.stdout:flush()
io.stdin:read "*a"

-- Shut down the database conn:
local helm_db = require "helm:helm/helm-db"
helm_db.close()

-- If helm is shutting down due to an error, print the stacktrace
-- now that the terminal is in a known-good state
if (onseq_err) then
   io.stderr:write(onseq_err)
end

-- Restore the global environment
setfenv(0, _G)
end -- of _helm
```

#### Call helm

```lua
return setfenv(_helm, __G)
```
