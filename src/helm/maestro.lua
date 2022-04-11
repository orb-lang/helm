















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




















local clone, insert = assert(table.clone), assert(table.insert)
local assert = assert(core.fn.assertfmt)
local _yield  = assert(core.thread.nest "actor" .yield)

function Maestro.activeKeymap(maestro)
   local keymap_list = maestro.modeS.raga.default_keymaps
   for _, keymap in ipairs(keymap_list) do
      keymap.bindings = maestro:dispatch { to = keymap.source,
                                          field  = keymap.name }
      assert(keymap.bindings, "Failed to retrieve bindings for " ..
               keymap.source .. "." .. keymap.name)
   end
   return Keymap(unpack(keymap_list))
end










local create, resume, status, yield = assert(coroutine.create),
                                      assert(coroutine.resume),
                                      assert(coroutine.status),
                                      assert(coroutine.yield)

function Maestro.act(maestro, msg)
   return pack(maestro:dispatch(msg))
end













function Maestro.delegate(maestro, msg)
   local to = msg.sendto or msg.to
   if to and to:find("^agents%.") then
      return maestro:act(msg)
   else
      return pack(_yield(msg))
   end
end










































local concat = assert(table.concat)

local function _dispatchOnly(maestro, event)
   local keymap = maestro:activeKeymap()
   local handlers = keymap(event)
   local tried = {}
   for _, handler in ipairs(handlers) do
      handler = clone(handler)
      -- #todo make this waaaaay more flexible
      if handler.n > 0 then
         handler[handler.n] = event
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
      maestro.modeS.raga.onTxtbufChanged(modeS)
    -- Treat contents_changed as implying cursor_changed
    -- only ever fire one of the two events
   elseif maestro.agents.edit.cursor_changed then
      maestro.modeS.raga.onCursorChanged(modeS)
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

