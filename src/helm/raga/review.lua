




local table = core.table
local clone, splice = assert(table.clone), assert(table.splice)
local RagaBase = require "helm:raga/base"
local Sessionbuf = require "helm:buf/sessionbuf"



local Review = clone(RagaBase, 2)
Review.name = "review"
Review.prompt_char = "💬"








function Review.quitHelm()
   local sesh_title = send { to = "hist.session", property = "session_title" }
   send { to = "agents.modal", method = "show",
      'Save changes to the session "' .. sesh_title .. '"?',
      "yes_no_cancel" }
end






Review.default_keymaps = {
   { source = "agents.session", name = "keymap_default"},
   { source = "agents.session.results_agent", name = "keymap_scrolling"}
}
splice(Review.default_keymaps, RagaBase.default_keymaps)














function Review.onShift(modeS)
   -- Hide the suggestion column so the review interface can occupy
   -- the full width of the terminal.
   -- #todo once we are able to switch between REPLing and review
   -- on the fly, we'll need to put this back as appropriate, but I
   -- think that'll come naturally once we have a raga stack.
   modeS.zones.suggest:hide()

   modeS:setStatusLine("review", modeS.hist.session.session_title)

   local modal_answer = send { to = "agents.modal", method = "answer" }
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



return Review

