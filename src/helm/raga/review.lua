




local table = core.table
local clone, splice = assert(table.clone), assert(table.splice)
local RagaBase = require "helm:raga/base"
local Sessionbuf = require "helm:buf/sessionbuf"



local Review = clone(RagaBase, 2)
Review.name = "review"
Review.prompt_char = "💬"
Review.keymap = require "helm:keymap/review"
Review.target = "agents.session"














function Review.onShift()
   -- Hide the suggestion column so the review interface can occupy
   -- the full width of the terminal.
   -- #todo once we are able to switch between REPLing and review
   -- on the fly, we'll need to put this back as appropriate, but I
   -- think that'll come naturally once we have a raga stack.
   send{ to = "zones.suggest", method = "hide" }

   local session_title = send{ to = "hist.session", field = "session_title" }
   send{ to = "agents.status", method = "update", "review", session_title }

   local modal_answer = send{ to = "agents.modal", method = "answer" }
   if modal_answer then
      if modal_answer == "yes" then
         send{ to = "hist.session", method = "save" }
      elseif modal_answer == "no" then
         send{ method = "quit" }
      end -- Do nothing on cancel
      return
   end

   -- #todo Replace with detection of if we're being
   -- created for the first time vs. a pop
   if send{ to = "zones.results.contents", field = "idEst" } ~= Sessionbuf then
      send{ method = "bindZone",
         "results", "session", Sessionbuf, {scrollable = true}}
   end
   local premise = send{ to = "agents.session", method = "selectedPremise" }
   if not premise then
      send{ to = "agents.session", method = "selectIndex", 1 }
      premise = send{ to = "agents.session", method = "selectedPremise" }
   end
   send{ to = "agents.edit", method = "update", premise and premise.title}
end



return Review

