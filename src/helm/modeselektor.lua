



















local core = require "qor:core"
local a = require "anterm:anterm"

local Historian  = require "helm:historian"
local Maestro    = require "helm:maestro"
local Zoneherd   = require "helm:zone"

local Resbuf    = require "helm:buf/resbuf"
local Stringbuf = require "helm:buf/stringbuf"
local Txtbuf    = require "helm:buf/txtbuf"

local Actor   = require "actor:actor"
local Valiant = require "valiant:valiant"

local Deque = require "deque:deque"

local bridge = require "bridge"



local cluster = require "cluster:cluster"
local s = require "status:status"
s.chatty = true






local new, ModeS, ModeS_M = cluster.genus(Actor)













-- Only needed by eval_env
local uv = require "luv"
local kit = require "valiant:replkit"

cluster.extendbuilder(new, function(_new, modeS, max_extent, writer, db)
   -- Some miscellany to copy and initialize
   modeS.max_extent = max_extent
   modeS.write = writer
   modeS.repl_top = ModeS.REPL_LINE

   -- Eval environment. Provide easy access to libraries and
   -- helm internals without polluting the actual global namespace.
   local eval_env = setmetatable({
      core = core,
      kit = kit,
      a = a,
      uv = uv,
      modeS = modeS
   }, { __index = _G })
   -- Unroll `core`, replacing `string`, `table` etc.
   core(eval_env)
   -- shim to replace core.uv with stock uv (ugly, fix)
   eval_env.uv = uv
   -- Create Actors
   modeS.valiant = Valiant(eval_env)
   modeS.hist  = Historian(db)
   modeS.zones = Zoneherd(modeS, writer)
   modeS.maestro = Maestro()

   return modeS
end)










function ModeS._pushMode(modeS, raga)
   modeS.maestro:pushMode(raga)
end













function ModeS.setup(modeS)
   local initial_raga = "nerf"
   modeS:_agent'status':update("default")
   -- Session-related setup
   local session_title = bridge.args.new_session or
                         bridge.args.session
   if session_title then
      modeS.hist:loadOrCreateSession(session_title)
      if bridge.args.new_session then
         -- Asked to create a session that already exists
         if modeS.hist.session.session_id then
            error('A session named "' .. session_title ..
                  '" already exists. You can review it with br helm -s.')
         end
         modeS:_agent'status':update("new_session", session_title)
      end
      if bridge.args.session then
         -- Asked to review a session that doesn't exist
         if not modeS.hist.session.session_id then
            error('No session named "' .. session_title ..
                  '" found. Use br helm -n to create a new session.')
         end
         -- If we are loading an existing session, start in review mode
         initial_raga = "session_review"
         modeS.hist.session:loadPremises()
      end
      modeS:_agent'session':update(modeS.hist.session)
   end

   if bridge.args.back or bridge.args.run then
      local deck
      if bridge.args.run then
         modeS.hist:loadPreviousRun()
         deck = modeS.hist.previous_run
      elseif bridge.args.back then
         deck = modeS.hist:loadRecentLines(bridge.args.back)
      end
      modeS:_agent'run_review':update(deck)
      initial_raga = 'run_review'
   end

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
   modeS :task() :_pushMode(initial_raga)

   if bridge.args.restart then
      modeS.hist:loadPreviousRun()
      local deque = Deque()
      deque:pushN(unpack(modeS.hist.previous_run))
      modeS:rerun(deque)
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
   local point = modeS.maestro.raga.getCursorPosition()
   if point then
      modeS.write(a.jump(point), a.cursor.show())
   end
   return modeS
end








function ModeS.paint(modeS)
   modeS.zones:paint(modeS)
   modeS:placeCursor()
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




function ModeS.delegator(modeS, msg)
   if msg.method == "pushMode" or msg.method == "popMode" or
      (msg.to and (msg.to == "raga" or msg.to:find("^agents%."))) then
      -- s:chat("sending a message to maestro: %s", ts(msg))
      return modeS.maestro(msg)
   else
      -- This is effectively modeS:super'delegate'(msg)
      return pack(modeS:dispatch(msg))
   end
end

function ModeS.delegate(modeS, msg)
   return modeS :task() :delegator(msg)
end










local clone = assert(core.table.clone)
function ModeS.inbox(modeS, msg)
   if msg.to == "modeS" then
      msg = clone(msg)
      msg.to = nil
      return modeS, msg
   end
   return modeS
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












function ModeS.tryAgain(modeS)
   modeS.action_complete = false
end









function ModeS._agent(modeS, agent_name)
   return modeS.maestro.agents[agent_name]
end

ModeS.agent = ModeS._agent -- not finishing this right now









function ModeS.quitHelm(modeS)
   -- #todo it's obviously terrible to have code specific to a particular
   -- piece of functionality in a supervisory class like this.
   -- To do this right, we probably need a proper raga stack. Then -n could
   -- push the Review raga onto the bottom of the stack, then Nerf. Quit
   -- at this point would be the result of the raga stack being empty,
   -- rather than an explicitly-invoked command, and Ctrl-Q would just pop
   -- the current raga. Though, a Ctrl-Q from e.g. Search would still want
   -- to actually quit, so it's not quite that simple...
   local session = modeS.hist.session
   if _Bridge.args.new_session and #session > 0 then
      local is_reviewing = false
      for i, raga in ipairs(modeS.maestro.raga_stack) do
         if raga == "session_review" then
            is_reviewing = true
            break
         end
      end
      if not is_reviewing then
         -- #todo Add the ability to change accepted status of
         -- the whole session to the review interface
         session.accepted = true
         modeS.maestro:pushMode("session_review")
         return
      end
   end
   -- #todo handle this better--as an event of sorts, maybe?
   -- @atman: wait, I have an idea!
   modeS.hist:close()
   modeS:_agent'status':update("quit")
   modeS.has_quit = true
end










local Round = require "helm:round"
function ModeS.rerunner(modeS, deque)
   -- #todo this should probably be on a RunAgent/Runner and invoked
   -- via some queued-Message mechanism, which would also take care of
   -- putting it in a coroutine. Until then, we do this.
   modeS:_agent'edit':clear()
   modeS.hist.stmts.savepoint_restart_session()
   local success, results
   for old_round in deque:popAll() do
      local new_round = old_round:newFromLine()
      success, results = modeS:eval(new_round.line)
      assert(results ~= "advance", "Incomplete line when restarting session")
      new_round.response[1] = results
      modeS.hist:append(new_round)
   end
   modeS.hist.stmts.release_restart_session()
   modeS.hist:toEnd()
   modeS:_agent'results':update(results)
end


function ModeS.rerun(modeS, deque)
   modeS :task() :rerunner(deque)
end








local rep = assert(string.rep)
function ModeS.openHelp(modeS)
   modeS:_agent'pager':update(("abcde "):rep(1000))
   modeS.maestro:pushMode "page"
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
   local line = modeS:send { to = "agents.edit",
                       method = 'contents' }
   local round = modeS.hist.desk
   round.line = line
   local success, results = modeS:eval(line)
   s:chat("we return from evaluation, success: %s", success)
   if not success and results == 'advance' then
      modeS:send { to = "agents.edit", method = 'endOfText'}
      round.response[1] = 'advance'
      return false -- Fall through to EditAgent nl binding
   else
      round.response[1] = results
      modeS:send { to = 'hist', method = 'append', round }
      -- Do this first because it clears the results area
      -- #todo this clearly means edit:clear() is doing too much, decouple
      modeS:send { to = "agents.edit", method = 'clear' }
      modeS:send { to = "agents.results", method = 'update', results }
   end
end

function ModeS.conditionalEval(modeS)
   if modeS:send { to = "agents.edit",
             method = 'shouldEvaluate'} then
      return modeS:userEval()
   else
      return false -- Fall through to EditAgent nl binding
   end
end






function ModeS.evalFromCursor(modeS)
   local to_run = Deque()
   for i = modeS.hist.cursor, modeS.hist.n do
      local round = modeS:send { to = "hist", method = "index", i }
      to_run:push(round)
   end
   modeS:rerun(to_run)
end






function ModeS.historyBack(modeS)
   -- Stash the edit-in-progress.
   -- #todo all of this will basically get rewritten with Card mode
   local linestash = modeS:send { to = "agents.edit", method = "contents" }
   modeS:send { to = 'hist', method = 'stashLine', linestash }
   local prev_round = modeS:send { to = "hist", method = "prev" }
   if prev_round then
      modeS:send { to = "agents.edit", method = "update", prev_round.line }
      modeS:send { to = "agents.results", method = "update", prev_round:result() }
   end
end

function ModeS.historyForward(modeS)
   local linestash = modeS:send { to = "agents.edit", method = "contents" }
   modeS:send { to = 'hist', method = 'stashLine', linestash }
   local next_round = modeS:send { to = "hist", method = "next" }
   if next_round then
      modeS:send { to = "agents.edit", method = "update", next_round.line }
      modeS:send { to = "agents.results", method = "update", next_round:result() }
   end
end











function ModeS.bindZone(modeS, zone_name, agent_name, buf_class, cfg)
   local zone = modeS.zones[zone_name]
   local agent = modeS:_agent(agent_name)
   zone:replace(buf_class(agent:window(), cfg))
end



return new

