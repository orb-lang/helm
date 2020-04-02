
























































































assert(meta, "must have meta in _G")










local c = import("singletons/color", "color")

local Txtbuf     = require "helm/txtbuf"
local Resbuf     = require "helm/resbuf" -- Not currently used...
local Rainbuf    = require "helm/rainbuf"
local Historian  = require "helm/historian"
local Lex        = require "helm/lex"
local Zoneherd   = require "helm/zone"
local Suggest    = require "helm/suggest"
local repr       = require "helm/repr"
local lua_parser = require "helm/lua-parser"

local Nerf      = require "helm/raga/nerf"
local Search    = require "helm/raga/search"
local Complete  = require "helm/raga/complete"

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
   local col = modeS.zones.command.tc + modeS.txtbuf.cursor.col - 1
   local row = modeS.zones.command.tr + modeS.txtbuf.cursor.row - 1
   modeS.write(a.colrow(col, row))
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




















ModeS.closet = { nerf =     { raga = Nerf,
                              lex  = Lex.lua_thor },
                 search =   { raga = Search,
                              lex  = Lex.null },
                 complete = { raga = Complete,
                              lex  = Lex.lua_thor } }

function ModeS.shiftMode(modeS, raga_name)
   -- Stash the current lexer associated with the current raga
   -- Currently we never change the lexer separate from the raga,
   -- but this will change when we start supporting multiple languages
   -- Guard against nil raga or lexer during startup
   if modeS.raga and modeS.lex then
      modeS.closet[modeS.raga.name].lex = modeS.lex
   end
   -- Switch in the new raga and associated lexer
   modeS.raga = modeS.closet[raga_name].raga
   modeS.lex = modeS.closet[raga_name].lex
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
     modeS.raga.txtbufChanged(modeS)
     modeS.txtbuf.contents_changed = false
   end
   if modeS.txtbuf.cursor_changed then
     modeS.raga.cursorChanged(modeS)
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
   local rb = instanceof(results, Rainbuf) and results or Rainbuf(results)
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

local loadNames = import("helm/repr/names", "loadNames")

function eval_M.__newindex(eval_ENV, key, value)
   local ok = pcall(newindexer, _G, key, value)
   if not ok then
      rawset(_G, key, value)
   end
   -- Use loadNames() to get the key added to all_symbols
   -- Should really divide up responsibility better between
   -- loadNames() and addName()
   loadNames{ [key] = value }
end



local function gatherResults(success, ...)
  return success, pack(...)
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

function ModeS.__eval(modeS, chunk, headless)
   if not headless then
      -- Getting ready to eval, cancel any active autocompletion
      modeS.suggest:cancel(modeS)
   end
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
   if parsed_chunk:select "Error" () then
      -- our parser isn't perfect, let's see what lua thinks
      local is_expr = loadstring(return_chunk)
      if is_expr then
         -- we have an expression which needs a return, and didn't
         -- detect it:
         chunk = return_chunk
         -- otherwise, we'll try our luck with the chunk, as-is
      end
   end
   local success, results
   local f, err = loadstring(chunk, 'REPL')
   if f then
      setfenv(f, eval_ENV)
      success, results = gatherResults(xpcall(f, debug.traceback))
      if not success then
         -- error
         results.frozen = true
      end
   else
      if err:match "'<eof>'$" then
         -- Lua expects some more input
         return modeS, 'advance'
      else
         -- make the error into the result
         results = { err,
                     n = 1,
                     frozen = true }
      end
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







local function _status__repr(status_table)
  return concat(status_table)
end

local _stat_M = meta {}
_stat_M.__repr = _status__repr

function _stat_M.clear(status_table)
  return setmetatable({}, getmetatable(status_table))
end







local function new(max_col, max_row, writer)
  local modeS = meta(ModeS)
  modeS.txtbuf = Txtbuf()
  modeS.hist  = Historian()
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
