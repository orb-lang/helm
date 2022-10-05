




local core = require "qor:core"
local clone = assert(core.table.clone)
local RagaBase = require "helm:raga/base"
local Reviewbuf = require "helm:buf/reviewbuf"



local Review = clone(RagaBase, 2)
local send = Review.send










function Review.onShift()
   -- Hide the suggestion column so the review interface can occupy
   -- the full width of the terminal.
   -- #todo once we are able to switch between REPLing and review
   -- on the fly, we'll need to put this back as appropriate, but I
   -- think that'll come naturally once we have a raga stack.
   send { to = "zones.suggest", method = "hide" }

   -- Retrieve the target of the actual concrete raga this is being called for
   local target = send { to = "raga", field = "target" }

   -- #todo Replace with detection of if we're being
   -- created for the first time vs. a pop
   if send { to = "zones.results.contents", field = "idEst" } ~= Reviewbuf then
      send { method = "bindZone",
         "results", target:gsub("^agents.",""), Reviewbuf, {scrollable = true}}
   end
end



return Review

