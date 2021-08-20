
























































































assert(meta, "must have meta in _G")










local Historian  = require "helm:historian"
local Maestro    = require "helm:maestro"
local Valiant = require "valiant:valiant"
local Zoneherd   = require "helm:zone"

local Resbuf    = require "helm:buf/resbuf"
local Stringbuf = require "helm:buf/stringbuf"
local Txtbuf    = require "helm:buf/txtbuf"



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



































local Nerf      = require "helm:raga/nerf"
local Search    = require "helm:raga/search"
local Complete  = require "helm:raga/complete"
local Page      = require "helm:raga/page"
local Modal     = require "helm:raga/modal"
local Review    = require "helm:raga/review"
local EditTitle = require "helm:raga/edit-title"

local Lex        = require "helm:lex"

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
      modeS.closet[modeS.raga.name].lex = modeS:agent'edit'.lex
   end
   -- Switch in the new raga and associated lexer
   modeS.raga = modeS.closet[raga_name].raga
   modeS:agent'edit':setLexer(modeS.closet[raga_name].lex)
   modeS.raga.onShift(modeS)
   -- #todo feels wrong to do this here, like it's something the raga
   -- should handle, but onShift feels kinda like it "doesn't inherit",
   -- like it's not something you should actually super-send, so there's
   -- not one good place to do this.
   modeS:agent'prompt':update(modeS.raga.prompt_char)
   return modeS
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
   if modeS:agent'edit'.contents_changed then
      modeS.raga.onTxtbufChanged(modeS)
    -- Treat contents_changed as implying cursor_changed
    -- only ever fire one of the two events
   elseif modeS:agent'edit'.cursor_changed then
      modeS.raga.onCursorChanged(modeS)
   end
   modeS:agent'edit'.contents_changed = false
   modeS:agent'edit'.cursor_changed = false
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
   modeS:agent'input_echo':update(event, command)
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









function ModeS.agent(modeS, agent_name)
   return modeS.maestro.agents[agent_name]
end











function ModeS.setResults(modeS, results)
   modeS:agent'results':update(results)
   return modeS
end

function ModeS.clearResults(modeS)
   return modeS:setResults(nil)
end











function ModeS.setStatusLine(modeS, status_name, ...)
   modeS:agent'status':update(status_name, ...)
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
   modeS.eval:restart()
   hist.stmts.savepoint_restart_session()
   for i = hist.cursor_start, top do
      local success, results = modeS.eval(tostring(hist[i]))
      assert(results ~= "advance", "Incomplete line when restarting session")
      hist:append(hist[i], results, success, modeS.session)
   end
   modeS.eval:reset()
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







local rep = assert(string.rep)
function ModeS.openHelp(modeS)
   modeS:agent'pager':update(("abcde "):rep(1000))
   modeS:shiftMode "page"
end











function ModeS.showModal(modeS, text, button_style)
   modeS:agent'modal':update(text, button_style)
   modeS:shiftMode "modal"
   return modeS
end








function ModeS.modalAnswer(modeS)
   return modeS:agent'modal':answer()
end







local concat = assert(table.concat)

local _stat_M = meta {}

function _stat_M.__repr(status_table)
   return concat(status_table)
end

function _stat_M.clear(status_table)
   return setmetatable({}, getmetatable(status_table))
end











function ModeS.bindZone(modeS, zone_name, agent_name, buf_class, cfg)
   local zone = modeS.zones[zone_name]
   local agent = modeS:agent(agent_name)
   zone:replace(buf_class(agent:window(), cfg))
end






local actor = require "core:cluster/actor"
local borrowmethod, getter = assert(actor.borrowmethod, actor.getter)

local function new(max_extent, writer, db)
   local modeS = meta(ModeS)

   -- Some miscellany to copy and initialize
   modeS.max_extent = max_extent
   modeS.write = writer
   modeS.repl_top = ModeS.REPL_LINE

   -- Create Actors (status isn't, but should be)
   modeS.eval = Valiant(__G)
   modeS.hist  = Historian(db)
   modeS.status = setmetatable({}, _stat_M)
   rawset(__G, "stat", modeS.status)
   modeS.zones = Zoneherd(modeS, writer)
   modeS.maestro = Maestro(modeS)

   -- Session-related setup
   -- #todo ugh this is clearly the wrong place/way to do this
   local session = modeS.hist.session
   modeS:agent'session':update(session)
   -- If we are loading an existing session, start in review mode
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

   -- Set up Agent <-> Agent interaction via borrowmethod
   local agents = modeS.maestro.agents
   local function borrowto(dst, src, name)
      dst[name] = borrowmethod(src, name)
   end
   borrowto(agents.suggest, agents.edit, "tokens")
   borrowto(agents.suggest, agents.edit, "replaceToken")
   borrowto(agents.prompt,  agents.edit, "continuationLines")
   agents.prompt.editTouched = getter(agents.edit, "touched")
   agents.search.searchText = borrowmethod(agents.edit, "contents")

   -- Set up common Agent -> Zone bindings
   -- Note we don't do results here because that varies from raga to raga
   -- The Txtbuf also needs a source of "suggestions" (which might be
   -- history-search results instead), but that too is raga-dependent
   modeS:bindZone("command",  "edit",       Txtbuf)
   modeS:bindZone("popup",    "pager",      Resbuf,    { scrollable = true })
   modeS:bindZone("prompt",   "prompt",     Stringbuf)
   modeS:bindZone("modal",    "modal",      Resbuf)
   modeS:bindZone("status",   "status",     Stringbuf)
   modeS:bindZone("stat_col", "input_echo", Resbuf)
   modeS:bindZone("suggest",  "suggest",    Resbuf)

   -- initial state
   modeS:shiftMode(modeS.raga_default)
   modeS.action_complete = true
   return modeS
end

ModeS.idEst = new



return new

