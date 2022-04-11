













--[[
profile = require("jit.profile")
profiled = {}
profile.start("li1", function(th, samples, vmmode)
   local d = profile.dumpstack(th, "pFZ;", 6)
   profiled[d] = (profiled[d] or 0) + samples
end)
--]]



assert(true)
if rawget(_G, "_Bridge") then
   _Bridge.helm = true
end













local __G = setmetatable({}, {__index = _G})
__G.__G = __G








local function _helm(_ENV)





setfenv(0, __G)

import = assert(require "core/module" . import)
meta = assert(require "core:cluster" . Meta)
core = require "core:core"
kit = require "valiant:replkit"
jit.vmdef = require "helm:helm/vmdef"
jit.p = require "helm:helm/ljprof"
sql = assert(sql, "sql must be in _G")







local s = require "status:status" ()
s.chatty = true
s.verbose = true
s.boring = false
ts = require "repr:repr" . ts_color














send = nil;
do
   local Message = require "actor:message"
   local thread = require "qor:core" . thread
   local nest = thread.nest "actor"
   local yield = assert(nest.yield)

   send = function (tab)
      return yield(Message(tab))
   end
end







uv = require "luv"
local usecolors
stdout = ""










if uv.guess_handle(1) == 'tty' then
   stdout = uv.new_tty(1, false)
   usecolors = true
else
   stdout = uv.new_pipe(false)
   uv.pipe_open(utils.stdout, 1)
   usecolors = false
end





local function write(...)
   uv.write(stdout, {...})
end



local concat = assert(table.concat)

function print(...)
   local n = select('#', ...)
   local arguments = {...}
   for i = 1, n do
      arguments[i] = tostring(arguments[i])
   end
   uv.write(stdout, concat(arguments, "\t") .. "\n")
end






if uv.guess_handle(0) ~= 'tty' or
   uv.guess_handle(1) ~= 'tty' then
   -- Bail if we're in a pipe
   error "stdio must be a tty"
end

local stdin = uv.new_tty(0, true)





a = require "anterm:anterm"
local Point = require "anterm:point"









local autothread = require "cluster:autothread"








local max_col, max_row = stdin:get_winsize()
local max_extent = Point(max_row, max_col)
modeS = require "helm/modeselektor" (max_extent, write)

autothread(modeS.setup, modeS)









local insert = assert(table.insert)

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
-- winsize_watch:start(500, 500, check_winsize)
local winsize_signal = uv.new_signal()
winsize_signal:start("sigwinch", check_winsize)




























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








local Set = require "qor:core" . set

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
   uv.walk(function(handle)
      if not (handle == stdin or handle == stdout) then
         local h_type = uv.handle_get_type(handle)
         if stoppable[h_type] then
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



















local wrap = assert(coroutine.wrap)

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
         local should_dispatch_all = false
         input_timer:start(5, 1, function()
            if not should_dispatch_all then
               should_dispatch_all = true
               return
            end
            input_timer:stop()
            if #input_buffer > 0 then
               autothread(dispatch_input, input_buffer, true)
            end
         end)
      end
   end
   consolidate_scroll_events(events)
   for _, event in ipairs(events) do
      modeS(event)
      s:bore "handled an event"
      -- Okay, if the action resulted in a quit, break out of the event loop
      if modeS.has_quit then
         shutDown(modeS)
         break
      end
   end
   s:bore "escaped dispatch_input"
end




local counter = 0
input_check:start(function()
      counter = counter + 1
   if should_dispatch_all and #input_buffer > 0 then
      autothread(dispatch_input, input_buffer, true)
   end
end)













local onseq_err

local function onseq(err, seq)
   if _ditch then return nil end
   local success, err_trace = xpcall(function()
      if err then error(err) end
      autothread(dispatch_input, input_buffer .. seq, false)
   end, debug.traceback)
   s:bore "escaped onseq"
   if not success then
      shutDown(modeS)
      onseq_err = err_trace
   end
end








local sighup_handler = uv.new_signal()
sighup_handler:start("sighup", function()
   shutDown(modeS)
end)




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





return setfenv(_helm, __G)

