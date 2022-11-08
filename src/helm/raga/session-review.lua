




local core = require "qor:core"
local clone = assert(core.table.clone)
local Review = require "helm:raga/review"



local SessionReview = clone(Review, 2)
local send = SessionReview.send

SessionReview.name = "session_review"
SessionReview.prompt_char = "💬"
SessionReview.keymap = require "helm:keymap/session-review"
SessionReview.target = "agents.session"










function SessionReview.onShift()
   local session_title = send { to = "hist.session", field = "session_title" }
   send { to = "agents.status", method = "update", "session_review", session_title }

   local modal_answer = send { to = "agents.modal", method = "answer" }
   if modal_answer then
      if modal_answer == "yes" then
         send { to = "hist.session", method = "save" }
      end
      if modal_answer ~= "cancel" then
         send { to = "modeS", method = "quitHelm" }
      end
      return
   end

   local premise = send { to = "agents.session", method = "selectedRound" }
   if not premise then
      send { to = "agents.session", method = "selectIndex", 1 }
      premise = send { to = "agents.session", method = "selectedRound" }
   end
   send { to = "agents.edit", method = "update", premise and premise.title}

   Review.onShift()
end



return SessionReview

