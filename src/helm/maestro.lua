















local EditAgent      = require "helm:agent/edit"
local InputEchoAgent = require "helm:agent/input-echo"
local ModalAgent     = require "helm:agent/modal"
local PagerAgent     = require "helm:agent/pager"
local PromptAgent    = require "helm:agent/prompt"
local ResultsAgent   = require "helm:agent/results"
local SearchAgent    = require "helm:agent/search"
local SessionAgent   = require "helm:agent/session"
local StatusAgent    = require "helm:agent/status"
local SuggestAgent   = require "helm:agent/suggest"

local assert = assert(core.fn.assertfmt)
local table = core.table






local cluster = require "cluster:cluster"
local Keymap = require "helm:keymap"

local Actor = require "actor:actor"

local new, Maestro, Maestro_M = cluster.genus(Actor)













function Maestro.act(maestro, msg)
   return pack(maestro:dispatch(msg))
end












local _yield  = assert(core.thread.nest "actor" .yield)

function Maestro.delegate(maestro, msg)
   local to = msg.sendto or msg.to
   if to and to:find("^agents%.") then
      return maestro:act(msg)
   else
      return pack(_yield(msg))
   end
end










































local clone, concat, insert = assert(table.clone),
                              assert(table.concat),
                              assert(table.insert)

local function _dispatchOnly(maestro, event)
   local handlers = maestro.modeS.raga.keymap(event)
   local tried = {}
   for _, handler in ipairs(handlers) do
      handler = clone(handler)
      -- #todo make this waaaaay more flexible
      if handler.n > 0 then
         handler[handler.n] = event
      end
      -- #todo using empty-string as a non-nil signpost
      -- should be able to refactor so this is not needed
      if (not handler.to) or handler.to == '' then
         handler.to = maestro.modeS.raga.target
      end
      -- #todo ugh, some way to dump a Message to a representative string?
      -- #todo also, this is assuming that all traversal is done in `sendto`,
      -- without nested messages--bad assumption, in general
      insert(tried, handler.method or handler.call)
      if maestro:dispatch(handler) ~= false then
         break
      end
   end
   if #tried == 0 then
      return nil
   else
      return concat(tried, ", ")
   end
end

function Maestro.eventDispatcher(maestro, event)
   local command = _dispatchOnly(maestro, event)
   if maestro.agents.edit.contents_changed then
      maestro.modeS.raga.onTxtbufChanged()
    -- Treat contents_changed as implying cursor_changed
    -- only ever fire one of the two events
   elseif maestro.agents.edit.cursor_changed then
      maestro.modeS.raga.onCursorChanged()
   end
   maestro.agents.edit.contents_changed = false
   maestro.agents.edit.cursor_changed = false
   return command
end

function Maestro.dispatchEvent(maestro, event)
   return maestro :task() :eventDispatcher(event)
end






cluster.extendbuilder(new, function(_new, maestro, modeS)
   -- #todo this is temporary until we sort out communication properly
   maestro.modeS = modeS
   maestro.agents = {
      edit       = EditAgent(),
      input_echo = InputEchoAgent(),
      modal      = ModalAgent(),
      pager      = PagerAgent(),
      prompt     = PromptAgent(),
      results    = ResultsAgent(),
      search     = SearchAgent(),
      session    = SessionAgent(),
      status     = StatusAgent(),
      suggest    = SuggestAgent(),
   }
   return maestro
end)




return new

