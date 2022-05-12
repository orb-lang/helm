# Session review

Raga for reviewing a previously\-saved session\.

```lua
local table = core.table
local clone, splice = assert(table.clone), assert(table.splice)
local RagaBase = require "helm:raga/base"
local Sessionbuf = require "helm:buf/sessionbuf"
```

```lua
local Review = clone(RagaBase, 2)
Review.name = "review"
Review.prompt_char = "💬"
Review.keymap = require "helm:keymap/review"
Review.target = "agents.session"
```


### Review\.onShift\(\)

We use the results area for displaying the lines and results
of the session in a Sessionbuf\-\-if one is not already there,
set it up\.

We use a modal to prompt the user to save on quit, so if a modal
answer is set, this is what it is about\. This is rather ugly, but
requires a whole bunch of refactoring of Ragas and Zones to improve\.

```lua
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
      end
      if modal_answer ~= "cancel" then
         send{ to = "modeS", method = "quitHelm" }
      end
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
```

```lua
return Review
```