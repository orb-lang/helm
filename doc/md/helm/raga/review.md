# Session review

Raga for reviewing a previously\-saved session\.

```lua
local core_table = require "core:table"
local clone, splice = assert(core_table.clone), assert(core_table.splice)
local yield = assert(coroutine.yield)
local RagaBase = require "helm:raga/base"
local Sessionbuf = require "helm:buf/sessionbuf"
```

```lua
local Review = clone(RagaBase, 2)
Review.name = "review"
Review.prompt_char = "💬"
```


### Quit handler

We intercept ^Q to prompt the user whether to save the session before quitting\.

```lua
function Review.quitHelm()
   local sesh_title = yield{ sendto = "hist.session", property = "session_title" }
   Review.agentMessage("modal", "show",
      'Save changes to the session "' .. sesh_title .. '"?',
      "yes_no_cancel")
end
```


### Keymaps

```lua
Review.default_keymaps = {
   { source = "agents.session", name = "keymap_default"},
   { source = "agents.session.results_agent", name = "keymap_scrolling"}
}
splice(Review.default_keymaps, RagaBase.default_keymaps)
```


### Review\.onShift\(modeS\)

We use the results area for displaying the lines and results
of the session in a Sessionbuf\-\-if one is not already there,
set it up\.

We use a modal to prompt the user to save on quit, so if a modal
answer is set, this is what it is about\. This is rather ugly, but
requires a whole bunch of refactoring of Ragas and Zones to improve\.

```lua
function Review.onShift(modeS)
   -- Hide the suggestion column so the review interface can occupy
   -- the full width of the terminal.
   -- #todo once we are able to switch between REPLing and review
   -- on the fly, we'll need to put this back as appropriate, but I
   -- think that'll come naturally once we have a raga stack.
   modeS.zones.suggest:hide()

   modeS:setStatusLine("review", modeS.hist.session.session_title)

   local modal_answer = Review.agentMessage("modal", "answer")
   if modal_answer then
      if modal_answer == "yes" then
         modeS.hist.session:save()
         modeS:quit()
      elseif modal_answer == "no" then
         modeS:quit()
      end -- Do nothing on cancel
      return
   end

   if modeS.zones.results.contents.idEst ~= Sessionbuf then
      modeS:bindZone("results", "session", Sessionbuf, {scrollable = true})
   end
   local premise = modeS:agent'session':selectedPremise()
   if not premise then
      modeS:agent'session':selectIndex(1)
      premise = modeS:agent'session':selectedPremise()
   end
   modeS:agent'edit':update(premise and premise.title)
end
```

```lua
return Review
```