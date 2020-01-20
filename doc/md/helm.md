# Helm


``helm`` is our repl.

```lua
if rawget(_G, "_Bridge") then
  _Bridge.helm = true
end
```
#### Intercept _G

We don't want to put ``helm`` into the environment of the codebase under
examination, so we replace the global environment with a table which falls
back to ``_G``.


Man.  I really like having first-class environments.

```lua
__G = setmetatable({}, {__index = _G})
```
### _helm

The entire module is setup as a function, to allow our new fenv
to be passed in.

```lua
local function _helm(_ENV)
```

No sense wasting a level of indent on a wrapper imho

```lua
setfenv(1, _ENV)

meta = require "core/meta" . meta

jit.vmdef = require "helm:helm/vmdef"
jit.p = require "helm:helm/ljprof"

sql = assert(sql, "sql must be in _G")
```
### Djikstra Insertion Point

Although we're not doing so yet, this is where we will set up Djikstra mode
for participating code.  We then push that up through the layers, and it lands
as close to C level as practical.

## Boot sequence

This boot sequence builds on Tim Caswell and the Luvit Author's repl example.


Couple pieces I'm not using but should:
```lua
uv = require "luv"

local usecolors
stdout = ""

if uv.guess_handle(1) == "tty" then
  stdout = uv.new_tty(1, false)
  usecolors = true
else
  stdout = uv.new_pipe(false)
  uv.pipe_open(utils.stdout, 1)
  usecolors = false
end

if not usecolors then
   ts = tostring
   -- #todo make this properly black and white ts
end
```

Not-blocking ``write`` and ``print``:

```lua
function write(...)
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
if uv.guess_handle(0) ~= "tty" or
   uv.guess_handle(1) ~= "tty" then
  -- Entry point for other consumers!
  error "stdio must be a tty"
end

local stdin = uv.new_tty(0, true)
```
```lua
a = require "anterm:anterm"
--watch = require "watcher"

```
## Modeselektor


```lua

-- Get window size and set up an idler to keep it refreshed

local max_col, max_row = uv.tty_get_winsize(stdin)

modeS = require "helm/modeselektor" (max_col, max_row)

local insert = assert(table.insert)
local function s_out(msg)
  insert(modeS.status, msg)
end

-- make a new 'status' instance
local s = require "singletons/status" (s_out)

local timer = uv.new_timer()
uv.timer_start(timer, 500, 500, function()
   max_col, max_row = uv.tty_get_winsize(stdin)
   if max_col ~= modeS.max_col or max_row ~= modeS.max_row then
      -- reflow screen.
      modeS.max_col, modeS.max_row = max_col, max_row
      modeS:reflow()
   end
end)
```
## Reader

The reader takes a stream of data from ``stdin``, asynchronously, and
processes it into tokens, which stream to the ``modeselektor``.


### process_escapes(seq)

```lua
local Codepoints = require "singletons/codepoints"
local byte, sub, char = assert(string.byte),
                        assert(string.sub),
                        assert(string.char)
local m_parse, is_mouse = a.mouse.parse_fast, a.mouse.ismousemove
local navigation, is_nav = a.navigation, a.is_nav

local function process_escapes(seq)
   if is_nav(seq) then
      return modeS("NAV", navigation[seq])
   elseif is_mouse(seq) then
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
   -- ^Q hard coded as quit, for now
   if head == 17 then
      _ditch = true
      modeS.zones.status:replace 'exiting repl, owo... 🐲'
      modeS:paint()
      uv.read_stop(stdin)
      uv.timer_stop(timer)
      return 0
   end
   -- Escape sequences
   if head == 27 then
      return process_escapes(seq)
   end
   -- Control sequences
   if navigation[seq] then
      return modeS("NAV", navigation[seq])
   elseif head <= 31 then
      local ctrl = "^" .. char(head + 64)
      return modeS("CTRL", ctrl)
   end
   -- Printables--break into codepoints in case of multi-char input sequence
   -- But first, optimize common case of single ascii printable
   -- Note that bytes <= 31 and 127 (DEL) will have been taken care of earlier
   if #seq == 1 and head < 128 then
      return modeS("ASCII", seq)
   else
      local points = Codepoints(seq)
      for i, pt in ipairs(points) do
         -- #todo handle decode errors here--right now we'll just insert an
         -- actual Unicode "replacement character"
         modeS(byte(pt) < 128 and "ASCII" or "UTF8", pt)
      end
   end
end
```
```lua


-- Get names for as many values as possible
-- into the colorizer
local names = require "helm/repr/names"
names.allNames(__G)

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

end -- of _helm
```
#### Call helm

```lua
return _helm
```
