













--[[
profile = require("jit.profile")
profiled = {}
profile.start("li1", function(th, samples, vmmode)
   local d = profile.dumpstack(th, "pF", 1)
   profiled[d] = (profiled[d] or 0) + samples
end)
--]]



if rawget(_G, "_Bridge") then
   _Bridge.helm = true
end












__G = setmetatable({}, {__index = _G})









local function _helm(_ENV)





setfenv(1, __G)
import = assert(require "core/module" . import)
meta = import("core/meta", "meta")
core = require "core:core"
jit.vmdef = require "helm:helm/vmdef"
jit.p = require "helm:helm/ljprof"
sql = assert(sql, "sql must be in _G")








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
   local orb_launch = uv.new_idle()
   orb_launch:start(function()
      orb_launch:stop()
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






local Codepoints = require "singletons/codepoints"
local byte, sub, char = assert(string.byte),
                        assert(string.sub),
                        assert(string.char)
local m_parse, is_mouse = a.mouse.parse_fast, a.mouse.ismousemove
local navigation = a.navigation

local function process_escapes(seq)
   if is_mouse(seq) then
      return modeS("MOUSE", m_parse(seq))
   elseif #seq == 2 and byte(seq, 2) < 128 then
      -- Meta
      local key = "M-" .. sub(seq,2,2)
      return modeS("ALT", key)
   elseif a.is_paste(seq) then
      return modeS("PASTE", a.parse_paste(seq))
   else
      return modeS("NYI", seq)
   end
end

-- uv, being an event loop, will sometimes keep reading after
-- we expect it to stop.
-- this prevents modeS from being reloaded in such circumstances.
--
-- maybe.

local _ditch = false

local function onseq(err,seq)
   if _ditch then return nil end
   if err then error(err) end

   local head = byte(seq)
   -- Special "navigation" sequences--this includes some escape sequences
   if navigation[seq] then
      modeS("NAV", navigation[seq])
   -- Other escape sequences
   elseif head == 27 then
      process_escapes(seq)
   -- Control sequences
   elseif head <= 31 then
      local ctrl = "^" .. char(head + 64)
      modeS("CTRL", ctrl)
   -- Printables--break into codepoints in case of multi-char input sequence
   -- But first, optimize common case of single ascii printable
   -- Note that bytes <= 31 and 127 (DEL) will have been taken care of earlier
   elseif #seq == 1 and head < 128 then
      modeS("ASCII", seq)
   else
      local points = Codepoints(seq)
      for i, pt in ipairs(points) do
         -- #todo handle decode errors here--right now we'll just insert an
         -- actual Unicode "replacement character"
         modeS(byte(pt) < 128 and "ASCII" or "UTF8", pt)
      end
   end
   -- Okay, if the action resulted in a quit, break out of the event loop
   if modeS.has_quit then
      _ditch = true
      uv.read_stop(stdin)
      uv.timer_stop(bounds_watch)
      if restart_watch then
         uv.timer_stop(restart_watch)
         lume.server:stop()
      end
   end
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

-- paint screen
modeS:paint()

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
      a.cursor.pop())



-- remove any spurious mouse inputs or other stdin stuff
io.stdin:read "*a"

-- Back to normal mode
uv.tty_reset_mode()

uv.stop()

io.stdout:flush()

-- nil out our extra copy of _G
_G_back = nil

end -- of _helm





return _helm

