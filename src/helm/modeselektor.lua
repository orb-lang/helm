
























































































assert(meta, "must have meta in _G")










local Set = require "set:set"
local Valiant = require "valiant:valiant"

local Txtbuf     = require "helm:buf/txtbuf"
local Resbuf     = require "helm:buf/resbuf"
local Historian  = require "helm:historian"
local Lex        = require "helm:lex"
local Zoneherd   = require "helm:zone"
local Suggest    = require "helm:suggest"
local Maestro    = require "helm:maestro"
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
   -- #todo Txtbuf should probably be directly aware that a lexer change
   -- requires a re-render
   modeS.txtbuf:beTouched()
   modeS.raga.onShift(modeS)
   modeS:updatePrompt()
   return modeS
end
























local function _check_shift(modeS)
   if modeS.shift_to then
      modeS:shiftMode(modeS.shift_to)
      modeS.shift_to = nil
   end
end

function ModeS.actOnce(modeS, event, old_cat_val)
   -- Try to dispatch the new-style event via keymap
   local command, args = modeS.maestro:translate(event)
   if command then
      modeS.maestro:dispatch(event, command, args)
   elseif old_cat_val then
      -- Okay, didn't find anything there, fall back to the old way
      local handled = modeS.raga(modeS, unpack(old_cat_val))
      if handled then
         command = 'LEGACY'
      end
   end
   _check_shift(modeS)
   if modeS.txtbuf.contents_changed then
      modeS.raga.onTxtbufChanged(modeS)
    -- Treat contents_changed as implying cursor_changed
    -- only ever fire one of the two events
   elseif modeS.txtbuf.cursor_changed then
      modeS.raga.onCursorChanged(modeS)
   end
    modeS.txtbuf.contents_changed = false
    modeS.txtbuf.cursor_changed = false
   -- Check shift_to again in case one of the cursor handlers set it
   _check_shift(modeS)
   return command
end



function ModeS.act(modeS, event, old_cat_val)
   local command
   repeat
      modeS.action_complete = true
      -- The raga may set action_complete to false to cause the command
      -- to be re-processed, most likely after a mode-switch
      local commandThisTime = modeS:actOnce(event, old_cat_val)
      command = command or commandThisTime
   until modeS.action_complete == true
   if not command then
      command = 'NYI'
   end
   -- Inform the input-echo agent of what just happened
   modeS.maestro.agents.input_echo:update(event, command)
   -- Update the prompt--obsolete once this is handled by a Window
   modeS:updatePrompt()
   -- Reflow in case command height has changed. Includes a paint.
   -- Don't allow errors encountered here to break this entire
   -- event-loop iteration, otherwise we become unable to quit if
   -- there's a paint error.
   local success, err = xpcall(modeS.reflow, debug.traceback, modeS)
   if not success then
      io.stderr:write(err, "\n")
      io.stderr:flush()
   end
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
   -- #todo ultimately this all wants to be handled by a Window, updating the
   -- contents of an existing Resbuf, so we won't have to think about whether
   -- or not what we're dealing with is already a Rainbuf
   if not results.is_rainbuf then
      local cfg = { scrollable = true }
      if type(results) == "string" then
         cfg.frozen = true
         results = { results, n = 1 }
      end
      results = Resbuf(results, cfg)
   end
   modeS.zones.results:replace(results)
   return modeS
end

function ModeS.clearResults(modeS)
   modeS:setResults ""
   return modeS
end











function ModeS.setStatusLine(modeS, status_name, ...)
   modeS.maestro.agents.status:update(status_name, ...)
end









function ModeS.setTxtbuf(modeS, txtbuf)
   -- Copy the lexer and suggestions over to the new Txtbuf
   -- #todo keep the same Txtbuf around (updating it using :replace())
   -- rather than swapping it out
   txtbuf.lex = modeS.txtbuf.lex
   txtbuf.suggestions = modeS.txtbuf.suggestions
   modeS.txtbuf = txtbuf
   modeS.txtbuf.cursor_changed = true
   modeS.txtbuf.contents_changed = true
   modeS.zones.command:replace(modeS.txtbuf)
   return modeS
end






local eval = Valiant(_G, __G)



local insert = assert(table.insert)
local keys = assert(core.keys)

function ModeS.eval(modeS)
   -- Getting ready to eval, cancel any active autocompletion
   modeS.suggest:cancel(modeS.txtbuf, modeS.zones.suggest)
   local line = tostring(modeS.txtbuf)
   local success, results = eval(line)
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
      -- Discard the second return value from :index
      -- or it will confuse the Txtbuf constructor rather badly
      local line = modeS.hist:index(i)
      modeS:setTxtbuf(Txtbuf(line))
      modeS:eval()
   end
end









function ModeS.quit(modeS)
   -- #todo handle this better--as an event of sorts, maybe?
   local session = modeS.hist.session
   if session.mode == "macro" and #session > 0 then
      session:save()
   end
   modeS:setStatusLine("quit")
   modeS.has_quit = true
end








function ModeS.restart(modeS)
   modeS :setStatusLine 'restart'
   -- remove existing result
   modeS :clearResults() :paint()
   -- perform rerun
   -- Replace results:
   local hist = modeS.hist
   local top = hist.n
   hist.n = hist.cursor_start - 1
   -- put instrumented require in restart mode
   eval:restart()
   hist.stmts.savepoint_restart_session()
   for i = hist.cursor_start, top do
      local success, results = eval(tostring(hist[i]))
      assert(results ~= "advance", "Incomplete line when restarting session")
      hist:append(hist[i], results, success, modeS.session)
   end
   eval:reset()
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
   return (contents and contents.is_rainbuf) and contents.value[1].value or nil
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

   -- Create Actors and other major sub-components
   modeS.txtbuf = Txtbuf()
   modeS.hist  = Historian(db)
   modeS.suggest = Suggest()
   modeS.status = setmetatable({}, _stat_M)
   rawset(__G, "stat", modeS.status)
   modeS.max_extent = max_extent
   modeS.write = writer
   modeS.repl_top = ModeS.REPL_LINE
   modeS.zones = Zoneherd(modeS, writer)
   modeS.maestro = Maestro(modeS)
   -- Bind Zones to bufs-of-windows-of-agents
   -- #todo this should definitely not be our responsibility
   modeS.txtbuf.suggestions = modeS.suggest:window()
   modeS.zones.command:replace(modeS.txtbuf)
   modeS.zones.suggest:replace(Resbuf(modeS.suggest:window()))
   -- If we are loading an existing session, start in review mode
   local session = modeS.hist.session
   if session.session_id then
      modeS.raga_default = "review"
      -- #todo we should probably do this in raga/review.onShift, but...
      modeS:setStatusLine("review", session.session_title)
   elseif session.session_title then
      -- ...only if we can move this too, and it's less clear where it
      -- should go--raga/nerf.onShift is a possibility, but doesn't feel
      -- like a very good one?
      modeS:setStatusLine(
         session.mode == "macro" and "macro" or "new_session",
         session.session_title)
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

