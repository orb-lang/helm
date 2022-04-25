























local act = require "actor:lib"
local borrowmethod = assert(act.borrowmethod)
local getter = assert(act.getter)



local Historian  = require "helm:historian"
local Maestro    = require "helm:maestro"
local Zoneherd   = require "helm:zone"

local Resbuf    = require "helm:buf/resbuf"
local Stringbuf = require "helm:buf/stringbuf"
local Txtbuf    = require "helm:buf/txtbuf"

local Actor   = require "actor:actor"
local Valiant = require "valiant:valiant"



local cluster = require "cluster:cluster"
local s = require "status:status"
s.chatty = true






local new, ModeS, ModeS_M = cluster.genus(Actor)













local _stat_M; -- we shouldn't need this anyway #todo remove

cluster.extendbuilder(new, function(_new, modeS, max_extent, writer, db)
   -- Some miscellany to copy and initialize
   modeS.max_extent = max_extent
   modeS.write = writer
   modeS.repl_top = ModeS.REPL_LINE

   -- Create Actors (status isn't, but should be)
   modeS.valiant = Valiant(__G)
   modeS.hist  = Historian(db)
   ---[[ This isn't how we should handle status,
   modeS.status = setmetatable({}, _stat_M)
   rawset(__G, "stat", modeS.status)
   -- so lets make this easy to knock out ]]
   modeS.zones = Zoneherd(modeS, writer)
   modeS.maestro = Maestro(modeS)

   return modeS
end)













function ModeS.setup(modeS)
   -- Session-related setup
   -- #todo ugh this is clearly the wrong place/way to do this
   local session = modeS.hist.session
   modeS:_agent'session':update(session)
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
   --  #Todo  This appears to be the only use of borrowmethod,
   --         if we can replace it with a message, we should
   agents.prompt.continuationLines = borrowmethod(agents.edit,
                                                  "continuationLines")
   agents.prompt.editTouched = getter(agents.edit, "touched")

   -- Set up common Agent -> Zone bindings
   -- Note we don't do results here because that varies from raga to raga
   -- The Txtbuf also needs a source of "suggestions" (which might be
   -- history-search results instead), but that too is raga-dependent
   modeS:bindZone("command",  "edit",       Txtbuf)
   modeS:bindZone("popup",    "pager",      Resbuf,
                  { scrollable = true })
   modeS:bindZone("prompt",   "prompt",     Stringbuf)
   modeS:bindZone("modal",    "modal",      Resbuf)
   modeS:bindZone("status",   "status",     Stringbuf)
   modeS:bindZone("stat_col", "input_echo", Resbuf)
   modeS:bindZone("suggest",  "suggest",    Resbuf)

   -- Load initial raga. Need to process yielded messages from `onShift`
   modeS :task() :shiftMode(modeS.raga_default)

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











function ModeS.task(modeS)
   return modeS.__tasker
end




function ModeS.delegator(modeS, msg)
   local to = msg.to or msg.sendto
   if to and to:find("^agents%.") then
      s:chat("sending a message to maestro: %s", ts(msg))
      return modeS.maestro(msg)
   else
      return pack(modeS:dispatch(msg))
   end
end

function ModeS.delegate(modeS, msg)
   return modeS :task() :delegator(msg)
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
      modeS.closet[modeS.raga.name].lex = modeS:_agent'edit'.lex
   end
   -- Switch in the new raga and associated lexer
   modeS.raga = modeS.closet[raga_name].raga
   modeS:_agent'edit':setLexer(modeS.closet[raga_name].lex)
   modeS.raga.onShift(modeS)
   -- #todo feels wrong to do this here, like it's something the raga
   -- should handle, but onShift feels kinda like it "doesn't inherit",
   -- like it's not something you should actually super-send, so there's
   -- not one good place to do this.
   modeS:_agent'prompt':update(modeS.raga.prompt_char)
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
      -- @atman: this is where quitting breaks if we forbid non-message
      -- return values in dispatch, not sure why.
      local commandThisTime = modeS.maestro:dispatchEvent(event)
      command = command or commandThisTime
   until modeS.action_complete == true
   if not command then
      command = 'NYI'
   end
   -- Inform the input-echo agent of what just happened
   -- #todo Maestro can do this once action_complete goes away
   modeS:_agent'input_echo':update(event, command)
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
   return modeS :task() :act(event)
end












function ModeS.tryAgain(modeS)
   modeS.action_complete = false
end









function ModeS._agent(modeS, agent_name)
   return modeS.maestro.agents[agent_name]
end

ModeS.agent = ModeS._agent -- not finishing this right now











function ModeS.setStatusLine(modeS, status_name, ...)
   modeS:_agent'status':update(status_name, ...)
end









function ModeS.quit(modeS)
   -- #todo it's obviously terrible to have code specific to a particular
   -- piece of functionality in a supervisory class like this.
   -- To do this right, we probably need a proper raga stack. Then -n could
   -- push the Review raga onto the bottom of the stack, then Nerf. Quit
   -- at this point would be the result of the raga stack being empty,
   -- rather than an explicitly-invoked command, and Ctrl-Q would just pop
   -- the current raga. Though, a Ctrl-Q from e.g. Search would still want
   -- to actually quit, so it's not quite that simple...
   -- Anyway. Also, don't bother saving the session if it has no premises...
   if _Bridge.args.new_session and modeS.raga_default ~= 'review' then
      local session = modeS.hist.session
      if #session > 0 then
         -- #todo Add the ability to change accepted status of
         -- the whole session to the review interface
         session.accepted = true
         -- Also, it's horribly hacky to change the "default" raga, but it's
         -- the only way to make Modal work properly. A proper raga stack
         -- would *definitely* fix this
         modeS:setDefaultMode("review")
         modeS:shiftMode("review")
         return
      end
   end
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










function ModeS.rerunner(modeS, deque)
   -- #todo this should probably be on a RunAgent/Runner and invoked
   -- via some queued-Message mechanism, which would also take care of
   -- putting it in a coroutine. Until then, we do this.
   modeS:_agent'edit':clear()
   modeS.hist.stmts.savepoint_restart_session()
   local success, results
   for line in deque:popAll() do
      success, results = modeS:eval(line)
      assert(results ~= "advance", "Incomplete line when restarting session")
      modeS.hist:append(line, results, success)
   end
   modeS.hist:toEnd()
   modeS:_agent'results':update(results)
end


function ModeS.rerun(modeS, deque)
   modeS :task() :rerunner(deque)
   local restart_idle = uv.new_idle()
   restart_idle:start(function()
   if modeS.hist:idling() then
      return nil
   end
   modeS.hist.stmts.release_restart_session()
      restart_idle:stop()
   end)
end








local rep = assert(string.rep)
function ModeS.openHelp(modeS)
   modeS:_agent'pager':update(("abcde "):rep(1000))
   modeS:shiftMode "page"
end

function ModeS.openHelpOnFirstKey(modeS)
   if modeS:agent'edit':isEmpty() then
      modeS:openHelp()
      return true
   else
      return false
   end
end











function ModeS.eval(modeS, line)
   return modeS.valiant(line)
end










function ModeS.userEval(modeS)
   local line = send { to = "agents.edit",
                       method = 'contents' }
   local success, results = modeS:eval(line)
   s:chat("we return from evaluation, success: %s", success)
   if not success and results == 'advance' then
      send { to = "agents.edit", method = 'endOfText'}
      return false -- Fall through to EditAgent nl binding
   else
      send { to = 'hist',
             method = 'append',
             line, results, success }

      send { to = 'hist', method = 'toEnd' }
      -- Do this first because it clears the results area
      -- #todo this clearly means edit:clear() is doing too much, decouple
      send { to = "agents.edit", method = 'clear' }
      send { to = "agents.results", method = 'update', results }
   end
end

function ModeS.conditionalEval(modeS)
   if send { to = "agents.edit",
             method = 'shouldEvaluate'} then
      return modeS:userEval()
   else
      return false -- Fall through to EditAgent nl binding
   end
end






function ModeS.evalFromCursor(modeS)
   local top = modeS.hist.n
   local cursor = modeS.hist.cursor
   for i = cursor, top do
      local line = send { to = "hist", method = "index", i }
      send { to = "agents.edit", method = "update", line }
      modeS:userEval()
   end
end






function ModeS.historyBack()
   -- If we're at the end of the history (the user was typing a new
   -- expression), save it before moving
   if send { to = 'hist', method = 'atEnd' } then
      local linestash = send { to = "agents.edit", method = "contents" }
      send { to = "hist", method = "append", linestash }
   end
   local prev_line, prev_result = send { to = "hist", method = "prev" }
   send { to = "agents.edit", method = "update", prev_line }
   send { to = "agents.results", method = "update", prev_result }
end

function ModeS.historyForward()
   local new_line, next_result = send { to = "hist", method = "next" }
   if not new_line then
      local old_line = send { to = "agents.edit", method = "contents" }
      local added = send { to = "hist", method = "append", old_line }
      if added then
         send { to = "hist", method = "toEnd" }
      end
   end
   send { to = "agents.edit", method = "update", new_line }
   send { to = "agents.results", method = "update", next_result }
end











function ModeS.bindZone(modeS, zone_name, agent_name, buf_class, cfg)
   local zone = modeS.zones[zone_name]
   local agent = modeS:_agent(agent_name)
   zone:replace(buf_class(agent:window(), cfg))
end



return new

