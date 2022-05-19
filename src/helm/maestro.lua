















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

local available_ragas = {
   nerf       = require "helm:raga/nerf",
   search     = require "helm:raga/search",
   complete   = require "helm:raga/complete",
   page       = require "helm:raga/page",
   modal      = require "helm:raga/modal",
   review     = require "helm:raga/review",
   edit_title = require "helm:raga/edit-title"
}

local cluster = require "cluster:cluster"
local Actor = require "actor:actor"

local assert = assert(core.fn.assertfmt)
local table = core.table







local new, Maestro, Maestro_M = cluster.genus(Actor)













function Maestro.act(maestro, msg)
   return pack(maestro:dispatch(msg))
end












local _yield  = assert(core.thread.nest "actor" .yield)

function Maestro.delegate(maestro, msg)
   if msg.method == "pushMode" or msg.method == "popMode" or
      (msg.to and msg.to:find("^agents%.")) then
      return maestro:act(msg)
   else
      return pack(_yield(msg))
   end
end










































local clone, concat, insert = assert(table.clone),
                              assert(table.concat),
                              assert(table.insert)

local function _dispatchOnly(maestro, event)
   local handlers = maestro.raga.keymap(event)
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
         handler.to = maestro.raga.target
      end
      -- #todo ugh, some way to dump a Message to a representative string?
      -- #todo also, this is assuming that all traversal is done in `to`,
      -- without nested messages--bad assumption, in general
      insert(tried, handler.method or handler.call)
      if send(handler) ~= false then
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
      maestro.raga.onTxtbufChanged()
    -- Treat contents_changed as implying cursor_changed
    -- only ever fire one of the two events
   elseif maestro.agents.edit.cursor_changed then
      maestro.raga.onCursorChanged()
   end
   maestro.agents.edit.contents_changed = false
   maestro.agents.edit.cursor_changed = false
   return command
end

function Maestro.dispatchEvent(maestro, event)
   return maestro :task() :eventDispatcher(event)
end























local function _shiftMode(maestro, raga_name)
   -- Stash the current lexer associated with the current raga
   -- Currently we never change the lexer separate from the raga,
   -- but this will change when we start supporting multiple languages
   -- Guard against nil raga or lexer during startup
   if maestro.raga then
      maestro.raga.onUnshift()
   end
   -- Switch in the new raga and associated lexer
   maestro.raga = available_ragas[raga_name]
   maestro.agents.edit:setLexer(maestro.raga.lex)
   maestro.raga.onShift()
   -- #todo feels wrong to do this here, like it's something the raga
   -- should handle, but onShift feels kinda like it "doesn't inherit",
   -- like it's not something you should actually super-send, so there's
   -- not one good place to do this.
   maestro.agents.prompt:update(maestro.raga.prompt_char)
   return maestro
end








local remove = assert(table.remove)

function Maestro.pushMode(maestro, raga)
   -- There will be at most one previous occurrence as long as nobody breaks
   -- the rules and messes with the stack outside these methods
   for i, elem in ipairs(maestro.raga_stack) do
      if elem == raga then
         remove(maestro.raga_stack, i)
         break
      end
   end
   insert(maestro.raga_stack, raga)
   return _shiftMode(maestro, raga)
end












function Maestro.popMode(maestro)
   remove(maestro.raga_stack)
   return _shiftMode(maestro, maestro.raga_stack[#maestro.raga_stack])
end






cluster.extendbuilder(new, function(_new, maestro)
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
   -- Raga stack starts out empty, though by first paint we'll have
   -- pushed an initial raga
   maestro.raga_stack = {}
   return maestro
end)




return new

