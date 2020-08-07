
























































































assert(meta, "must have meta in _G")










local c = import("singletons/color", "color")
local Set = require "set:set"
local valiant = require "valiant:valiant"

local Txtbuf     = require "helm/txtbuf"
local Resbuf     = require "helm/resbuf" -- Not currently used...
local Rainbuf    = require "helm/rainbuf"
local Historian  = require "helm/historian"
local Lex        = require "helm/lex"
local Zoneherd   = require "helm/zone"
local Suggest    = require "helm/suggest"
local repr       = require "helm/repr"
local lua_parser = require "helm/lua-parser"

local concat               = assert(table.concat)
local sub, gsub, rep, find = assert(string.sub),
                             assert(string.gsub),
                             assert(string.rep),
                             assert(string.find)

local ts = repr.ts_color




local ModeS = meta()


























ModeS.REPL_LINE = 2







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
   local point = modeS.zones.command.bounds:origin() + modeS.txtbuf.cursor - 1
   modeS.write(a.jump(point))
   return modeS
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























function ModeS.continuationLines(modeS)
   return modeS.txtbuf and #modeS.txtbuf.lines - 1 or 0
end







function ModeS.updatePrompt(modeS)
   local prompt = modeS.raga.prompt_char .. " " .. ("\n..."):rep(modeS:continuationLines())
   modeS.zones.prompt:replace(prompt)
   return modeS
end




















local Nerf      = require "helm/raga/nerf"
local Search    = require "helm/raga/search"
local Complete  = require "helm/raga/complete"
local Page      = require "helm/raga/page"

ModeS.closet = { nerf =     { raga = Nerf,
                              lex  = Lex.lua_thor },
                 search =   { raga = Search,
                              lex  = Lex.null },
                 complete = { raga = Complete,
                              lex  = Lex.lua_thor },
                 page =     { raga = Page,
                              lex  = Lex.null } }

function ModeS.shiftMode(modeS, raga_name)
   -- Stash the current lexer associated with the current raga
   -- Currently we never change the lexer separate from the raga,
   -- but this will change when we start supporting multiple languages
   -- Guard against nil raga or lexer during startup
   if modeS.raga then
      modeS.raga.onUnshift(modeS)
      modeS.closet[modeS.raga.name].lex = modeS.lex
   end
   -- Switch in the new raga and associated lexer
   modeS.raga = modeS.closet[raga_name].raga
   modeS.lex = modeS.closet[raga_name].lex
   modeS.raga.onShift(modeS)
   modeS:updatePrompt()
   return modeS
end
























function ModeS.actOnce(modeS, category, value)
   local handled = modeS.raga(modeS, category, value)
   if modeS.shift_to then
      modeS:shiftMode(modeS.shift_to)
      modeS.shift_to = nil
   end
   if modeS.txtbuf.contents_changed then
     modeS.raga.onTxtbufChanged(modeS)
     modeS.txtbuf.contents_changed = false
   end
   if modeS.txtbuf.cursor_changed then
     modeS.raga.onCursorChanged(modeS)
     modeS.txtbuf.cursor_changed = false
   end
   return handled
end



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
   modeS.zones.command:replace(modeS.txtbuf)
   -- Reflow in case command height has changed. Includes a paint.
   modeS:updatePrompt():reflow()
   collectgarbage()
   return modeS
end





function ModeS.__call(modeS, category, value)
  return modeS:act(category, value)
end









local instanceof = import("core/meta", "instanceof")

function ModeS.setResults(modeS, results)
   results = results or ""
   if results == "" then
      modeS.zones.results:replace(results)
      return modeS
   end
   if type(results) == "string" then
      results = { results, n = 1, frozen = true }
   end
   local rb = Rainbuf(results)
   rb.scrollable = true
   modeS.zones.results:replace(rb)
   return modeS
end









function ModeS.setTxtbuf(modeS, txtbuf)
   modeS.txtbuf = txtbuf
   modeS.txtbuf.cursor_changed = true
   modeS.txtbuf.contents_changed = true
   return modeS
end







local evaluate = assert(valiant.eval)



local insert = assert(table.insert)
local keys = assert(core.keys)

function ModeS.__eval(modeS, chunk, headless)
   if not modeS.original_packages then
      -- we cache the package.loaded packages here, to preserve
      -- everything loaded by helm and modeselektor, while letting
      -- us hot-reload anything "require"d at the repl.
      modeS.original_packages = Set(keys(package.loaded))
   end
   if not headless then
      -- Getting ready to eval, cancel any active autocompletion
      modeS.suggest:cancel(modeS)
   end
   local success, results = evaluate(chunk)
   if not success and results == 'advance' then
      return modeS, results
   end

   if not headless then
      modeS.hist:append(modeS.txtbuf, results, success)
      modeS.hist.cursor = modeS.hist.n + 1
      if success then
         modeS.hist.result_buffer[modeS.hist.n] = results
      end
      modeS:setResults(results)
      modeS:setTxtbuf(Txtbuf())
   end

   return modeS, results
end

function ModeS.eval(modeS)
   local _, advance = modeS:__eval(tostring(modeS.txtbuf))
   if advance == 'advance' then
      modeS.txtbuf:advance()
   end
   return modeS
end









function ModeS.evalFromCursor(modeS)
   local top = modeS.hist.n
   local cursor = modeS.hist.cursor
   for i = cursor, top do
      modeS.txtbuf = modeS.hist:index(i)
      modeS:eval()
   end
end








local deepclone = assert(core.deepclone)

function ModeS.restart(modeS)
   modeS.zones.status:replace "Restarting an repl ↩️"
   -- we might want to do this again, so:
   local _G_backback = deepclone(_G_back)
   -- package has to be handled separately because it's in the registry
   local _loaded = package.loaded
   _G = _G_back
   -- we need the existing __G, not the empty clone, in _G:
   _G.__G = __G
   -- and we need the new _G, not the old one, as the index for __G:
   getmetatable(__G).__index = _G
   -- and the one-and-only package.loaded
   _G.package.loaded = _loaded
   _G_back = _G_backback
   -- we also need to clear the registry of package.loaded
   local current_packages = Set(keys(package.loaded))
   local new_packages = current_packages - modeS.original_packages
   for pack in pairs(new_packages) do
      package.loaded[pack] = nil
   end
   -- perform rerun
   -- Replace results:
   local hist = modeS.hist
   local top = hist.cursor - 1
   local session_count = hist.cursor - hist.cursor_start
   hist.cursor = hist.cursor_start
   hist.n  = hist.n - session_count
   hist.conn:exec "SAVEPOINT restart_session;"
   for i = modeS.hist.cursor_start, top do
      local _, results = modeS:__eval(tostring(hist[i]), true)
      if results ~= 'advance' then
         hist.n = hist.n + 1
         hist.result_buffer[hist.n] = results
         hist:persist(hist[i], results)
      end
   end
   hist.cursor = top + 1
   hist.n = #hist
   modeS:paint()
   uv.timer_start(uv.new_timer(), 2000, 0,
                  function()
                     modeS.zones.status:replace(modeS.prompt_lines.default)
                     modeS:paint()
                  end)
   local restart_idle = uv.new_idle()
   restart_idle:start(function()
      if #hist.idlers > 0 then
         return nil
      end
      hist.conn:exec "RELEASE restart_session;"
      restart_idle:stop()
   end)
   return modeS
end







function ModeS.openHelp(modeS)
   local rb = Rainbuf{ ("abcde "):rep(1000), n = 1 }
   modeS.zones.popup:replace(rb)
   modeS.shift_to = "page"
end








local function _status__repr(status_table)
  return concat(status_table)
end

local _stat_M = meta {}
_stat_M.__repr = _status__repr

function _stat_M.clear(status_table)
  return setmetatable({}, getmetatable(status_table))
end







local function new(max_col, max_row, writer, db)
  local modeS = meta(ModeS)
  modeS.txtbuf = Txtbuf()
  modeS.hist  = Historian(db)
  modeS.suggest = Suggest()
  modeS.status = setmetatable({}, _stat_M)
  rawset(__G, "stat", modeS.status)
  modeS.max_col = max_col
  modeS.max_row = max_row
  modeS.write = writer
  -- this will be replaced with Zones
  modeS.l_margin = 4
  modeS.r_margin = 80
  modeS.repl_top = ModeS.REPL_LINE
  modeS.zones = Zoneherd(modeS, writer)
  modeS.prompt_lines = { default = "an repl, plz reply uwu 👀" }
  modeS.zones.status:replace(modeS.prompt_lines.default)
  -- initial state
  modeS:shiftMode(modeS.raga_default)
  modeS.action_complete = true
  modeS.shift_to = nil
  return modeS
end

ModeS.idEst = new



return new
