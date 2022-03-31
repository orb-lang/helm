# Modeselektor

  `helm` itself sets up and launches Modeselektor, which is the master and
commander of `helm`\.

Modeselektor is an Actor, the point of entry for input, and ultimate
coordinator of the responses to those actions\.

## Design

`helm` parses keystrokes into events, and provides them to `modeselektor`\.

It then runs the event loop, and upon exit will tear down the raw terminal
environment it set up\.  Everything between happens from Modeselektor\.


#### imports


##### actor library

I'd like to stop using the two remaining idioms here:

```lua
local act = require "actor:lib"
local borrowmethod = assert(act.borrowmethod)
local getter = assert(act.getter)
```

```lua
local Historian  = require "helm:historian"
local Maestro    = require "helm:maestro"
local Zoneherd   = require "helm:zone"

local Resbuf    = require "helm:buf/resbuf"
local Stringbuf = require "helm:buf/stringbuf"
local Txtbuf    = require "helm:buf/txtbuf"

local Actor   = require "actor:actor"
local Valiant = require "valiant:valiant"
```

```lua
local cluster = require "cluster:cluster"
local core    = require "qor:core"
local s = require "status:status"
s.chatty = true
```


### Modeselektor

```lua
local new, ModeS, ModeS_M = cluster.genus(Actor)
```


## builder

Currently, we split construction between `new`, which we extend with
cluster, and the subsequent `:setup` method, which relies on the instance
having its metatable\.

A mechanism for doing this natively in cluster will exist, but currently
does not\.

```lua
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
```


### ModeS:setup\(modeS\)

  Properly this should be a post\-metatable extension function through a
cluster protocol, because it's not valid to create a Modeselektor without
calling `:setup` immediately after\.

There's only the one, and we don't currently mock it or extend it, although we
should mock it\.

```lua
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
```


### idEst \#Todo remove

`new` is a new\-style cluster constructor, so it will work with `idest()`, but
since we don't use that juuust yet, here we go:

```lua
ModeS.idEst = new
```


#### Line and Prompt Width Defaults

```lua
ModeS.REPL_LINE = 2
ModeS.PROMPT_WIDTH = 3
```


### ModeS:errPrint\(modeS, category, value\)

Debug aide\.

```lua
function ModeS.errPrint(modeS, log_stmt)
   modeS.zones.suggest:replace(log_stmt)
   modeS:paint()
   return modeS
end
```


### ModeS:placeCursor\(\)

Places the cursor where it belongs on the screen\.
We delegate determining where this is to the Raga\.

```lua
local Point = require "anterm:point"
function ModeS.placeCursor(modeS)
   local point = modeS.raga.getCursorPosition(modeS)
   if point then
      modeS.write(a.jump(point), a.cursor.show())
   end
   return modeS
end
```

### ModeS:paint\(\)

Paint the screen\. Primarily handled by the same method on the Zoneherd,
but we must also place the cursor\.

```lua
function ModeS.paint(modeS)
   modeS.zones:paint(modeS)
   modeS:placeCursor(modeS)
   return modeS
end
```


### ModeS:reflow\(\)

```lua
function ModeS.reflow(modeS)
   modeS.zones:reflow(modeS)
   modeS:paint()
   return modeS
end
```

```lua
local create, resume, status = assert(coroutine.create),
                               assert(coroutine.resume),
                               assert(coroutine.status)
```


### ModeS:task\(\) :method\(\.\.\.\)

Calls a Modeselektor method in 'task' mode, where it will catch and dispatch
any messages which are yielded by anything up the call stack\.

The tasker is reusable, and built during construction\.

```lua
function ModeS.task(modeS)
   return modeS.__tasker
end
```


```lua
function ModeS.delegator(modeS, msg)
   if msg.sendto and msg.sendto:find("^agents%.") then
      s:chat("sending a message to maestro: %s", ts(msg))
      return modeS.maestro(msg)
   else
      return pack(modeS:dispatch(msg))
   end
end

function ModeS.delegate(modeS, msg)
   return modeS :task() :delegator(msg)
end
```


### Prompts and modes / ragas

Time to add modes to the `modeselektor`\! Yes, I'm calling it `raga`
and that's a bit precious, but it's an important and heavily\-used concept,
so it's good to have a unique name\.

Right now everything works on the default mode, "nerf":

```lua
ModeS.raga_default = "nerf"
```

We'll need several basic modes and some ways to do overlay, and we need a
single source of truth as to what mode we're in\.

The entrance for that should be a single function, `ModeS:shiftMode(raga)`,
which takes care of all stateful changes to `modeselektor` needed to enter
the mode\.  One thing it will do is set the field `raga` to the parameter\.

As a general rule, we want mode changes to work generically, by changing
the functions attached to `(category, value)` pairs\.

But sometimes we'll want a bit of logic that dispatches on the mode directly,
repainting is a good example of this\.

The next mode we're going to write is `"search"`\.


### ModeS:shiftMode\(raga\)

The `modeselektor`, as described in the prelude, is a stateful and hypermodal
`repl` environment\.

`shiftMode` is the gear stick which drives the state\. It encapsulates the
state changes needed to switch between them\.


#### ModeS\.closet

A storage table for modes and other things we aren't using and need to
retrieve\.

```lua
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
```


#### ModeS:setDefaultMode\(raga\_name\)

\#todo
raga stack session review needs to in order for Modal to work right\. This
method is here because Messages can't set properties\-\-which, should they be
able to? It's kinda the odd one out when they can already mimic lots of other
Lua syntax, but actual use of it is questionable\.\.\.

```lua
function ModeS.setDefaultMode(modeS, raga_name)
   modeS.raga_default = raga_name
end
```


## act

`act` dispatches a single event\.

```lua
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
```

To keep `act` itself replaceable, we look it up on each call:

```lua

function ModeS.__call(modeS, event)
   return modeS :task() :act(event)
end
```


### ModeS:tryAgain\(\)

Causes re\-dispatch of the input event currently being processed by setting
\`action\_complete = false\`\.

\#todo
Maestro\.

```lua
function ModeS.tryAgain(modeS)
   modeS.action_complete = false
end
```


### ModeS:agent\(agent\_name\)

Shorthand for referring to `Agent`s, which are stored on `Maestro`, but which
we often talk to directly\.

```lua
function ModeS._agent(modeS, agent_name)
   return modeS.maestro.agents[agent_name]
end

ModeS.agent = ModeS._agent -- not finishing this right now
```


### ModeS:setStatusLine\(status\_name, format\_args\.\.\.\)

Sets the status line at the top of the screen by updating the StatusAgent\.

\#todo

```lua

function ModeS.setStatusLine(modeS, status_name, ...)
   modeS:_agent'status':update(status_name, ...)
end
```


### ModeS:quit\(\)

Marks the modeselektor as ready to quit \(the actual teardown will happen
in the outer event\-loop code in helm\.orb\)

```lua
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
```


### ModeS:rerun\(deque\)

Re\-run the statements in the provided `deque`, displaying the results of the
last one executed\. Does not reset `_G`, though the caller may do that if they
choose\.

```lua
function ModeS.rerunner(modeS, deque)
   -- #todo this should probably be on a RunAgent/Runner and invoked
   -- via some queued-Message mechanism, which would also take care of
   -- putting it in a coroutine. Until then, we do this.
   modeS:_agent'edit':clear()
   modeS.hist.stmts.savepoint_restart_session()
   local success, results
   for line in deque:popAll() do
      success, results = modeS.eval(line)
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
```

### ModeS:openHelp\(\)

Opens a simple help screen\.

```lua
local rep = assert(string.rep)
function ModeS.openHelp(modeS)
   modeS:_agent'pager':update(("abcde "):rep(1000))
   modeS:shiftMode "page"
end
```


### ModeS:eval\(line\)

Creates a coroutine and runs it manual transmission\.

```lua
local ev_nest = core.thread.nest 'evaluate'

function ModeS.eval(modeS, line)
   local co = ev_nest.create(function()
      return modeS.valiant(line)
   end)
   s:chat "beginning coroutinized evaluation protocol"
   local ok, success, results = ev_nest.resume(co)
   -- never gets here??
   s:chat("success %s, results %s", tostring(success), tostring(results))
   -- handle not ok, now we just pass through
   return success, results
end
```


### ModeS:bindZone\(zone\_name, agent\_name, buf\_class, cfg\)

Changes the Zone `zone_name` to display content from the Agent named `agent_name`\.

\#todo
as arguments is probably not the best choice\.

```lua
function ModeS.bindZone(modeS, zone_name, agent_name, buf_class, cfg)
   local zone = modeS.zones[zone_name]
   local agent = modeS:_agent(agent_name)
   zone:replace(buf_class(agent:window(), cfg))
end
```

```lua
return new
```























