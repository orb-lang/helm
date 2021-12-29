













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
meta = import("core/meta", "meta")
core = require "core:core"
kit = require "valiant:replkit"
jit.vmdef = require "helm:helm/vmdef"
jit.p = require "helm:helm/ljprof"
sql = assert(sql, "sql must be in _G")











local yield = assert(coroutine.yield)
local Message = require "actor:message"

function send(tab)
   return yield(Message(tab))
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
--watch = require "watcher"







-- Get window size and set up an idler to keep it refreshed

local MOUSE_MAX = 223

local function bind_pane(dim1, dim2)
   dim1 = dim1 > MOUSE_MAX and MOUSE_MAX or dim1
   dim2 = dim2 > MOUSE_MAX and MOUSE_MAX or dim2
   return dim1, dim2
end

local max_col, max_row = bind_pane(uv.tty_get_winsize(stdin))
local max_extent = Point(max_row, max_col)



modeS = require "helm/modeselektor" (max_extent, write)
local insert = assert(table.insert)
local function s_out(msg)
   insert(modeS.status, msg)
end

-- make a new 'status' instance
local s = require "status:status" (s_out)

local bounds_watch = uv.new_timer()
uv.timer_start(bounds_watch, 500, 500, function()
   max_col, max_row = uv.tty_get_winsize(stdin)
   if Point(max_row, max_col) ~= modeS.max_extent then
      modeS.max_extent = Point(bind_pane(max_row, max_col))
      -- Mark all zones as touched since we don't know the state of the screen
      -- (some terminals, iTerm for sure, will attempt to reflow the screen
      -- themselves and fail miserably)
      for _, zone in ipairs(modeS.zones) do
         zone.touched = true
      end
      modeS:reflow()
   end
end)













local restart_watch, lume = nil, nil

if _Bridge.args.listen then
   uv.new_timer():start(0, 0, function()
      local orb = require "orb:orb"
      lume = orb.lume(uv.cwd())
      lume :run() :serve(true)
      restart_watch = uv.new_timer()
      uv.timer_start(restart_watch, 500, 500, function()
         if lume.has_file_change then
            modeS:restart()
            lume.has_file_change = nil
         end
      end)
   end)
end





























local _ditch = false
local parse_input = require "anterm:input-parser"

local should_dispatch_all = false
local input_idle = uv.new_idle()
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

local function dispatch_input(seq, dispatch_all)
   -- Clear the flag and timer indicating whether we should clear down the
   -- input buffer this cycle. Note that we must explicitly stop the timer
   -- because we need to give it a repeat value to kick the event loop along
   should_dispatch_all = false
   input_idle:stop()
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
         -- Use an idler to wait until the beginning of the *next* loop to
         -- set the flag that will cause our check handler to clear the
         -- input buffer. An idler is the type of handle that (a) runs before
         -- blocking for input, and (b) causes the loop *not* to actually
         -- block for input. It will only ever run once (see above).
         input_idle:start(function() should_dispatch_all = true end)
      end
   end
   consolidate_scroll_events(events)
   for _, event in ipairs(events) do
      modeS(event)
      -- Okay, if the action resulted in a quit, break out of the event loop
      if modeS.has_quit then
         _ditch = true
         uv.read_stop(stdin)
         bounds_watch:stop()
         input_idle:stop()
         input_check:stop()
         if restart_watch then
            restart_watch:stop()
            lume.server:stop()
         end
         break
      end
   end
end

input_check:start(function()
   if should_dispatch_all and #input_buffer > 0 then
      dispatch_input(input_buffer, true)
   end
end)

local function onseq(err,seq)
   if _ditch then return nil end
   if err then error(err) end
   dispatch_input(input_buffer .. seq, false)
end





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
      a.mouse.track(true)
)
uv.read_start(stdin, onseq)

-- initial layout and paint screen
modeS:reflow()

--[[ stop profiler if we're using it to measure startup time
profile.stop()
--]]

-- main loop
local retcode =  uv.run('default')

-- Shut down the database conn:
local helm_db = require "helm:helm/helm-db"
helm_db.close()


retcode = uv.run 'default'

-- Teardown: Mouse tracking off, restore main screen and cursor
write(a.mouse.track(false),
      a.paste_bracketing(false),
      a.alternate_screen(false),
      a.cursor.pop(),
      a.cursor.show())

-- Back to normal mode and finish tearing down uv
uv.tty_reset_mode()
uv.stop()

-- Make sure the terminal processes all of the above,
-- then remove any spurious mouse inputs or other stdin stuff
io.stdout:flush()
io.stdin:read "*a"

-- Restore the global environment
setfenv(0, _G)
end -- of _helm





return setfenv(_helm, __G)

