
























































































assert(meta, "must have meta in _G")
assert(write, "must have write in _G")










local c = (require "singletons/color").color

local Txtbuf     = require "helm/txtbuf"
local Resbuf     = require "helm/resbuf" -- Not currently used...
local Rainbuf    = require "helm/rainbuf"
local Historian  = require "helm/historian"
local Lex        = require "helm/lex"
local Zoneherd   = require "helm/zone"
local repr       = require "helm/repr"
local lua_parser = require "helm/lua-parser"

local names     = require "helm/repr/names"

local Nerf      = require "helm/nerf"
local Search    = require "helm/search"

local concat               = assert(table.concat)
local sub, gsub, rep, find = assert(string.sub),
                             assert(string.gsub),
                             assert(string.rep),
                             assert(string.find)

local ts = repr.ts_color




local ModeS = meta()
























ModeS.modes = Nerf





ModeS.REPL_LINE = 2






ModeS.special = {}







function ModeS.errPrint(modeS, log_stmt)
   modeS.zones.suggest:replace(log_stmt)
   modeS:paint()
   return modeS
end




















local STAT_ICON = "◉ "

local function tf(bool)
  return bool and c["true"]("t") or c["false"]("f")
end

local function mouse_paint(m)
   return c.userdata(STAT_ICON)
      .. a.magenta(m.button) .. ": "
      .. a.bright(m.kind) .. " "
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







function ModeS.placeCursor(modeS)
   local col = modeS.zones.command.tc + modeS.txtbuf.cursor.col - 1
   local row = modeS.zones.command.tr + modeS.txtbuf.cursor.row - 1
   write(a.colrow(col, row))
end







function ModeS.paint(modeS)
   modeS.zones:paint(modeS)
   return modeS
end






function ModeS.reflow(modeS)
   modeS.zones:reflow(modeS)
   modeS:paint()
   return modeS
end









ModeS.raga_default = "nerf"


























ModeS.prompts = { nerf   = "👉 ",
                  search = "⁉️ " }








function ModeS.continuationLines(modeS)
   return modeS.txtbuf and #modeS.txtbuf.lines - 1 or 0
end







function ModeS.updatePrompt(modeS)
   local prompt = modeS.prompts[modeS.raga] .. ("\n..."):rep(modeS:continuationLines())
   modeS.zones.prompt:replace(prompt)
end




















ModeS.closet = { nerf = { modes = Nerf,
                          lex   = Lex.lua_thor },
                 search = { modes = Search,
                            lex   = c.base } }

function ModeS.shiftMode(modeS, raga)
   if raga == "search" then
      -- stash current lexer
      -- #todo do this in a less dumb way
      modeS.closet[modeS.raga].lex = modeS.lex
   end
   modeS.lex = modeS.closet[raga].lex
   modeS.modes = modeS.closet[raga].modes
   modeS.raga = raga
   modeS:updatePrompt()
   return modeS
end








local function _firstCharHandler(modeS, category, value)
   local shifted = false
   if category == "ASCII" then
      if value == "/" then
         modeS:shiftMode "search"
         shifted = true
      end
   end
   modeS.firstChar = false
   return shifted
end














local assertfmt, iscallable = require "core/string" . assertfmt,
                              require "core/table" . iscallable

function ModeS.act(modeS, category, value)
   assertfmt(modeS.modes[category], "no category %s in modeS", category)
   -- catch special handlers first
   if modeS.special[value] then
      return modeS.special[value](modeS, category, value)
   end
   local icon = _make_icon(category, value)
   -- Special first-character handling
   if modeS.firstChar and not (category == "MOUSE" or category == "NAV") then
      modeS.zones.results:replace ""
      local shifted = _firstCharHandler(modeS, category, value)
      if shifted then
        goto final
      end
   end
   -- Dispatch on value if possible
   if type(modeS.modes[category]) == "table"
      and modeS.modes[category][value] then
      modeS.modes[category][value](modeS, category, value)
   -- Or on category if the whole category is callable
   elseif iscallable(modeS.modes[category]) then
      modeS.modes[category](modeS, category, value)
   -- Otherwise display the unknown command
   else
      local val_rep = string.format("%q",value):sub(2,-2)
      icon = _make_icon("NYI", category .. ": " .. val_rep)
   end

   ::final::
   if modeS.raga == "search" then
      local searchResult = modeS.hist:search(tostring(modeS.txtbuf))
      modeS.zones.results:replace(searchResult)
   end
   -- Replace zones
   modeS.zones.stat_col:replace(icon)
   modeS.zones.command:replace(modeS.txtbuf)
   modeS:updatePrompt()
   -- Reflow in case command height has changed. Includes a paint.
   modeS:reflow()
   collectgarbage()
end





function ModeS.__call(modeS, category, value)
  return modeS:act(category, value)
end



















local eval_ENV = {}
local eval_M = {}
setmetatable(eval_ENV, eval_M)


local function indexer(Env, key)
   return Env[key]
end

function eval_M.__index(eval_ENV, key)
   local ok, value = pcall(indexer, _G, key)
   if ok and value ~= nil then
      return value
   end
   ok, value = pcall(indexer, __G, key)
   if ok and value ~= nil then
      return value
   end
   return nil
end

local function newindexer(Env, key, value)
   Env[key] = value
end

local addName = assert(names.addName)

function eval_M.__newindex(eval_ENV, key, value)
   local ok = pcall(newindexer, _G, key, value)
   if not ok then
      rawset(_G, key, value)
   end
   addName { [key] = value }
end



local function gatherResults(success, ...)
  local n = select('#', ...)
  return success, { n = n, ... }
end



local result_repr_M = meta {}

function result_repr_M.__repr(result)
  local i = 1
  return function()
     if i <= #result then
       i = i + 1
       return result[i - 1]
     end
  end
end



local insert = assert(table.insert)

function ModeS.__eval(modeS, chunk, no_append)
   -- check for leading =, old-school style
   local head = sub(chunk, 1, 1)
   if head == "=" then -- take pity on old-school Lua hackers
       chunk = "return " .. sub(chunk,2)
   end
   -- add "return" and see if it parses
   local return_chunk = "return " .. chunk
   local parsed_chunk = lua_parser(return_chunk)
   if not parsed_chunk:select "Error" () then
      chunk = return_chunk
   else
      -- re-parse the chunk
      parsed_chunk = lua_parser(chunk)
   end
   -- #Todo tinker with the chunk, finding $1-type vars
   local success, results
   local f, err = loadstring(chunk, 'REPL')
   if f then
      setfenv(f, eval_ENV)
      success, results = gatherResults(xpcall(f, debug.traceback))
      if success then
         -- successful call
         if results.n > 0 then
            local rb = Rainbuf(results)
            modeS.zones.results:replace(rb)
         else
            modeS.zones.results:replace ""
         end
      else
         -- error
         results.frozen = true
      end
   else
      if err:match "'<eof>'$" then
         -- Lua expects some more input, advance the txtbuf
         modeS.txtbuf:advance()
         write(a.colrow(1, modeS.repl_top + 1) .. "...")
         return true
      else
         -- make the error into the result
         results = { err,
                     n = 1,
                     frozen = true}
      end
   end
   if not no_append then
     modeS.zones.results:replace(results)
     modeS.hist:append(modeS.txtbuf, results, success)
     if success then
        modeS.hist.result_buffer[modeS.hist.n] = results
     end
     modeS.hist.cursor = modeS.hist.n
   else
     return results
   end
end

function ModeS.eval(modeS)
   modeS:__eval(tostring(modeS.txtbuf))
end








function ModeS.restart(modeS)
   -- we might want to do this again, so:
   modeS.zones.status:replace "Restarting an repl ↩️"
   local _G_backback = core.deepclone(_G_back)
   _G = _G_back
   -- we need the existing __G, not the empty clone, in _G:
   _G.__G = __G
   -- and we need the new _G, not the old one, as the index for __G:
   getmetatable(__G).__index = _G
   _G_back = _G_backback
   -- perform rerun
   -- Replace results:
   local hist = modeS.hist
   local top = hist.cursor - 1
   local session_count = hist.cursor - hist.cursor_start
   hist.cursor = hist.cursor_start
   hist.n  = hist.n - session_count
   for i = modeS.hist.cursor_start, top do
      local results = modeS:__eval(tostring(hist[i]), true)
      hist.n = hist.n + 1
      hist.result_buffer[hist.n] = results
      hist:persist(hist[i], results)
   end
   hist.cursor = top
   hist.n = #hist
   modeS:paint()
   uv.timer_start(uv.new_timer(), 2000, 0,
                  function()
                     modeS.zones.status:replace(modeS.prompt_lines.default)
                     modeS:paint()
                  end)
end







local function _status__repr(status_table)
  return concat(status_table)
end

local _stat_M = meta {}
_stat_M.__repr = _status__repr

function _stat_M.clear(status_table)
  return setmetatable({}, getmetatable(status_table))
end







local function new(max_col, max_row)
  local modeS = meta(ModeS)
  modeS.txtbuf = Txtbuf()
  modeS.hist  = Historian()
  modeS.status = setmetatable({}, _stat_M)
  rawset(__G, "stat", modeS.status)
  modeS.max_col = max_col
  modeS.max_row = max_row
  -- this will be replaced with Zones
  modeS.l_margin = 4
  modeS.r_margin = 80
  modeS.repl_top = ModeS.REPL_LINE
  modeS.zones = Zoneherd(modeS, write)
  modeS.prompt_lines = { default = "an repl, plz reply uwu 👀" }
  modeS.zones.status:replace(modeS.prompt_lines.default)
  -- initial state
  modeS.firstChar = true
  modeS:shiftMode(modeS.raga_default)
  return modeS
end

ModeS.idEst = new



return new
