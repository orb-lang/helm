# Nerf mode


``nerf`` is the default mode for the repl.


-  #Todo


  - [ ]  All of the content for the first draft is in ``modeselektor``, so
         let's transfer that.


  - [?]  There should probably be a metatable for Mode objects.


#### includes

This is copypasta from Modeselektor, but yeah, we'll need most of this.

```lua
assert(meta, "must have meta in _G")
assert(write, "must have write in _G")
assert(ts, "must have ts in _G")
```
```lua
local Txtbuf    = require "txtbuf"
local Resbuf    = require "resbuf" -- Not currently used...
local Historian = require "historian"
local Lex       = require "lex"
local a         = require "anterm"

local concat         = assert(table.concat)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)
```
## Nerf


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

While we will likely want a metatable going forward, this will do for now:

```lua
Nerf = { ASCII  = ASCII,
                NAV    = NAV,
                CTRL   = CTRL,
                ALT    = ALT,
                MOUSE  = MOUSE,
                NYI    = NYI }
```
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

```
```lua

function NAV.LEFT(modeS, category, value)
   local moved = modeS.txtbuf:left()
   if not moved and modeS.txtbuf.cur_row ~= 1 then
      local cur_row = modeS.txtbuf.cur_row - 1
      modeS.txtbuf.cur_row = cur_row
      modeS.txtbuf.cursor = #modeS.txtbuf.lines[cur_row] + 1
   end
end

function NAV.RIGHT(modeS, category, value)
   local moved = modeS.txtbuf:right()
   if not moved and modeS.txtbuf.cur_row ~= #modeS.txtbuf.lines then
      modeS.txtbuf.cur_row = modeS.txtbuf.cur_row + 1
      modeS.txtbuf.cursor = 1
   end
end

function NAV.RETURN(modeS, category, value)
   -- eval or split line
   local eval = modeS.txtbuf:nl()
   if eval then
     modeS:nl()
     local more = modeS:eval()
     if not more then
       modeS.txtbuf = Txtbuf()
       modeS.firstChar = true
     end
     modeS.hist.cursor = modeS.hist.cursor + 1
   end
end

local function _modeShiftOnEmpty(modeS)
   local buf = tostring(modeS.txtbuf)
   if buf == "" then
      modeS:shiftMode(modeS.raga_default)
      modeS.firstChar = true
      modeS:clearResults()
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
   _modeShiftOnEmpty(modeS)
end

function NAV.DELETE(modeS, category, value)
   local shrunk = modeS.txtbuf:d_fwd()
   if shrunk then
      write(a.stash())
      write(a.rc(modeS:replLine() + 1, 1))
      write(a.erase.line())
      write(a.pop())
   end
   _modeShiftOnEmpty(modeS)
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
```lua
return Nerf
```
