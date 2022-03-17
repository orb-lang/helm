
























































































assert(meta, "must have meta in _G")










local Historian  = require "helm:historian"
local Maestro    = require "helm:maestro"
local Valiant = require "valiant:valiant"
local Zoneherd   = require "helm:zone"

local Resbuf    = require "helm:buf/resbuf"
local Stringbuf = require "helm:buf/stringbuf"
local Txtbuf    = require "helm:buf/txtbuf"



local ModeS = meta {}

























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








local create, resume, status = assert(coroutine.create),
                               assert(coroutine.resume),
                               assert(coroutine.status)

local dispatchmessage = assert(require "actor:actor" . dispatchmessage)

function ModeS.processMessagesWhile(modeS, fn)
   local coro = create(fn)
   local msg_ret = { n = 0 }
   local ok, msg
   while true do
      ok, msg = resume(coro, unpack(msg_ret))
      if not ok then
         error(msg .. "\nIn coro:\n" .. debug.traceback(coro))
      elseif status(coro) == "dead" then
         -- End of body function, pass through the return value
         return msg
      end

      msg_ret = modeS:delegate(msg)
   end
end



local function _delegate(modeS, msg)
   if msg.sendto and msg.sendto:find("^agents%.") then
      return modeS.maestro(msg)
   else
      return pack(dispatchmessage(modeS, msg))
   end
end

function ModeS.delegate(modeS, msg)
   local coro = create(_delegate)
   local msg_ret = pack(modeS, msg)
   local ok
   while true do
      ok, msg = resume(coro, unpack(msg_ret))
         if not ok then
         error(msg .. "\nIn coro:\n" .. debug.traceback(coro))
      elseif status(coro) == "dead" then
         -- End of body function, pass through the return value
         return msg
      end
      msg_ret = modeS:delegate(msg)
   end
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
   if raga_name == "default" then
      raga_name = modeS.raga_default
   end
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












function ModeS.setDefaultMode(modeS, raga_name)
   modeS.raga_default = raga_name
end



















function ModeS.act(modeS, event)
   local command;
   repeat
      modeS.action_complete = true
      -- The raga may set action_complete to false to cause the command
      -- to be re-processed, most likely after a mode-switch
      local commandThisTime = modeS.maestro:dispatch(event)
      command = command or commandThisTime
   until modeS.action_complete == true
   if not command then
      command = 'NYI'
   end
   -- Inform the input-echo agent of what just happened
   -- #todo Maestro can do this once action_complete goes away
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






function ModeS.__call(modeS, event)
   local co = create(modeS.act)
   local msg_ret = pack(modeS, event)
   local ok, msg
   while true do
      ok, msg = resume(co, unpack(msg_ret))
      if not ok then
         error(msg .. "\nIn coro:\n" .. debug.traceback(co))
      elseif status(co) == "dead" then
         -- End of body function, pass through the return value
         return msg
      end

      msg_ret = modeS:delegate(msg)
   end
end












function ModeS.tryAgain(modeS)
   modeS.action_complete = false
end









function ModeS.agent(modeS, agent_name)
   return modeS.maestro.agents[agent_name]
end











function ModeS.setStatusLine(modeS, status_name, ...)
   modeS:agent'status':update(status_name, ...)
end









function ModeS.quit(modeS)
   -- #todo handle this better--as an event of sorts, maybe?
   -- @atman: wait, I have an idea!
   modeS.hist:close()
   -- this is just to commit the end of the run, right now
   local session = modeS.hist.session
   if session.mode == "macro" and #session > 0 then
      session:save()
   end
   modeS:setStatusLine("quit")
   modeS.has_quit = true
end










function ModeS.rerun(modeS, deque)
   -- #todo this should probably be on a RunAgent/Runner and invoked
   -- via some queued-Message mechanism, which would also take care of
   -- putting it in a coroutine. Until then, we do this.
   modeS:processMessagesWhile(function()
      modeS:agent'edit':clear()
      modeS.hist.stmts.savepoint_restart_session()
      local success, results
      for line in deque:popAll() do
         success, results = modeS.eval(line)
         assert(results ~= "advance", "Incomplete line when restarting session")
         modeS.hist:append(line, results, success)
      end
      modeS.hist:toEnd()
      modeS:agent'results':update(results)
   end)
   local restart_idle = uv.new_idle()
   restart_idle:start(function()
      if #modeS.hist.idlers > 0 then
         return nil
      end
      modeS.hist.stmts.release_restart_session()
      restart_idle:stop()
   end)
end









local rep = assert(string.rep)
function ModeS.openHelp(modeS)
   modeS:agent'pager':update(("abcde "):rep(1000))
   modeS:shiftMode "page"
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






local actor = require "actor:actor"
local borrowmethod, getter = assert(actor.borrowmethod, actor.getter)

local function new(max_extent, writer, db)
   local modeS = setmetatable({}, ModeS)

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
   elseif session.session_title then
      -- #todo should probably do this somewhere else--maybe raga/nerf.onShift,
      -- but it's certainly not Nerf-specific...
      modeS:setStatusLine(
         session.mode == "macro" and "macro" or "new_session",
         session.session_title)
   else
      modeS:setStatusLine("default")
   end

   -- #todo this interaction is messy, would be nice to be able to use yielded
   -- messages but it happens at render time, outside a coroutine.
   local agents = modeS.maestro.agents
   agents.prompt.continuationLines = borrowmethod(agents.edit,
                                                  "continuationLines")
   agents.prompt.editTouched = getter(agents.edit, "touched")

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

   -- Load initial raga. Need to process yielded messages from `onShift`
   modeS:processMessagesWhile(function()
      modeS:shiftMode(modeS.raga_default)
   end)

   -- hackish: we check the historian for a deque of lines to load and if
   -- we have it, we just eval them into existence.
   if modeS.hist.reloads then
      modeS:rerun(modeS.hist.reloads)
      --modeS.hist.reloads = nil
   end

   modeS.action_complete = true
   return modeS
end

ModeS.idEst = new



return new

