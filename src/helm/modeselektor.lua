
























































































assert(meta, "must have meta in _G")










local Set = require "set:set"
local valiant = require "valiant:valiant"

local Txtbuf     = require "helm:txtbuf"
local Resbuf     = require "helm:resbuf"
local Historian  = require "helm:historian"
local Lex        = require "helm:lex"
local Zoneherd   = require "helm:zone"
local Suggest    = require "helm:suggest"
local repr       = require "repr:repr"
local lua_parser = require "helm:lua-parser"

local concat               = assert(table.concat)
local sub, gsub, rep, find = assert(string.sub),
                             assert(string.gsub),
                             assert(string.rep),
                             assert(string.find)

local ts = repr.ts_color




local ModeS = meta()


























ModeS.REPL_LINE = 2
ModeS.PROMPT_WIDTH = 3







function ModeS.errPrint(modeS, log_stmt)
   modeS.zones.suggest:replace(log_stmt)
   modeS:paint()
   return modeS
end




















local c = import("singletons:color", "color")

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








local Point = require "anterm:point"
function ModeS.placeCursor(modeS)
   local point = modeS.raga.getCursorPosition(modeS)
   if point then
      modeS.write(a.jump(point), a.cursor.show())
   end
   return modeS
end








function ModeS.paint(modeS)
   modeS.zones:paint(modeS)
   modeS:placeCursor(modeS)
   return modeS
end






function ModeS.reflow(modeS)
   modeS.zones:reflow(modeS)
   modeS:paint()
   return modeS
end











ModeS.raga_default = "nerf"























function ModeS.continuationLines(modeS)
   return modeS.txtbuf and #modeS.txtbuf - 1 or 0
end







function ModeS.updatePrompt(modeS)
   local prompt = modeS.raga.prompt_char .. " " .. ("\n..."):rep(modeS:continuationLines())
   modeS.zones.prompt:replace(prompt)
   return modeS
end




















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
      modeS.zones.command:beTouched()
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
   modeS:updatePrompt()
   -- Reflow in case command height has changed. Includes a paint.
   -- Don't allow errors encountered here to break this entire
   -- event-loop iteration, otherwise we become unable to quit if
   -- there's a paint error.
   xpcall(modeS.reflow, function(err)
      io.stderr:write(err, "\n", debug.traceback(), "\n")
      io.stderr:flush()
   end, modeS)
   collectgarbage()
   return modeS
end





function ModeS.__call(modeS, category, value)
   return modeS:act(category, value)
end









local instanceof = import("core:meta", "instanceof")

function ModeS.setResults(modeS, results)
   results = results or ""
   if results == "" then
      modeS.zones.results:replace(results)
      return modeS
   end
   local cfg = { scrollable = true }
   if type(results) == "string" then
      cfg.frozen = true
      results = { results, n = 1 }
   end
   modeS.zones.results:replace(Resbuf(results, cfg))
   return modeS
end










ModeS.status_lines = { default = "an repl, plz reply uwu 👀",
                       quit    = "exiting repl, owo... 🐲",
                       restart = "restarting an repl ↩️",
                       review  = 'reviewing session "%s"' }
ModeS.status_lines.macro = ModeS.status_lines.default .. ' (macro-recording "%s")'
ModeS.status_lines.new_session = ModeS.status_lines.default .. ' (recording "%s")'

function ModeS.setStatusLine(modeS, status_name, ...)
   local status_line = modeS.status_lines[status_name]:format(...)
   modeS.zones.status:replace(status_line)
   return modeS
end









function ModeS.setTxtbuf(modeS, txtbuf)
   -- Copy the lexer and suggestions over to the new Txtbuf
   -- #todo keep the same Txtbuf around (updating it using :replace())
   -- rather than swapping it out
   txtbuf.lex = modeS.txtbuf.lex
   txtbuf.active_suggestions = modeS.txtbuf.active_suggestions
   modeS.txtbuf = txtbuf
   modeS.txtbuf.cursor_changed = true
   modeS.txtbuf.contents_changed = true
   modeS.zones.command:replace(modeS.txtbuf)
   return modeS
end






local evaluate, req = assert(valiant(_G, __G))



local insert = assert(table.insert)
local keys = assert(core.keys)

function ModeS.eval(modeS)
   -- Getting ready to eval, cancel any active autocompletion
   modeS.suggest:cancel(modeS)
   local line = tostring(modeS.txtbuf)
   local success, results = evaluate(line)
   if not success and results == 'advance' then
      modeS.txtbuf:endOfText()
      modeS.txtbuf:nl()
   else
      modeS.hist:append(line, results, success)
      modeS.hist.cursor = modeS.hist.n + 1
      modeS:setResults(results)
      modeS:setTxtbuf(Txtbuf())
   end

   return modeS
end









function ModeS.evalFromCursor(modeS)
   local top = modeS.hist.n
   local cursor = modeS.hist.cursor
   for i = cursor, top do
      modeS:setTxtbuf(Txtbuf(modeS.hist:index(i)))
      modeS:eval()
   end
end









function ModeS.quit(modeS)
   -- #todo handle this better--as an event of sorts, maybe?
   if modeS.hist.session.mode == "macro" then
      modeS.hist.session:save()
   end
   modeS:setStatusLine("quit")
   modeS.has_quit = true
end








function ModeS.restart(modeS)
   modeS :setStatusLine 'restart'
   -- remove existing result
   modeS :setResults "" :paint()
   -- perform rerun
   -- Replace results:
   local hist = modeS.hist
   local top = hist.n
   hist.n = hist.cursor_start - 1
   -- put instrumented require in restart mode
   req:restart()
   hist.stmts.savepoint_restart_session()
   for i = hist.cursor_start, top do
      local success, results = evaluate(tostring(hist[i]))
      assert(results ~= "advance", "Incomplete line when restarting session")
      hist:append(hist[i], results, success, modeS.session)
   end
   req:reset()
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







function ModeS.openHelp(modeS)
  -- #todo this should be a generic Rainbuf
   local rb = Resbuf{ ("abcde "):rep(1000), n = 1 }
   modeS.zones.popup:replace(rb)
   modeS.shift_to = "page"
end











function ModeS.showModal(modeS, text, button_style)
   local modal_info = Modal.newModel(text, button_style)
   -- #todo make DialogModel a kind of Rainbuf? Or use a generic one?
   modeS.zones.modal:replace(Resbuf{ modal_info, n = 1 })
   modeS.shift_to = "modal"
   return modeS
end









function ModeS.modalAnswer(modeS)
   local contents = modeS.zones.modal.contents
   return (contents and contents.is_rainbuf) and contents[1].value or nil
end







local function _status__repr(status_table)
   return concat(status_table)
end

local _stat_M = meta {}
_stat_M.__repr = _status__repr

function _stat_M.clear(status_table)
   return setmetatable({}, getmetatable(status_table))
end















local deepclone = assert(core.deepclone)
local function new(max_extent, writer, db)
   local modeS = meta(ModeS)

   modeS.txtbuf = Txtbuf()
   modeS.hist  = Historian(db)
   modeS.suggest = Suggest()
   modeS.status = setmetatable({}, _stat_M)
   rawset(__G, "stat", modeS.status)
   modeS.max_extent = max_extent
   modeS.write = writer
   modeS.repl_top = ModeS.REPL_LINE
   modeS.zones = Zoneherd(modeS, writer)
   modeS.zones.command:replace(modeS.txtbuf)
   -- If we are loading an existing session, start in review mode
   if _Bridge.args.session then
      modeS.raga_default = "review"
      modeS:setStatusLine("review", _Bridge.args.session)
   elseif _Bridge.args.new_session then
      modeS:setStatusLine("new_session", _Bridge.args.new_session)
   elseif _Bridge.args.macro then
      modeS:setStatusLine("macro", _Bridge.args.macro)
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



return new

