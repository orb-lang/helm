




local clone = assert(require "core:table" . clone)
local RagaBase = require "helm:raga/base"
local Txtbuf = require "helm:txtbuf"
local Sessionbuf = require "helm:sessionbuf"



local Review = clone(RagaBase, 2)
Review.name = "review"
Review.prompt_char = "💬"








function Review.onShift(modeS)
   modeS.zones.results:replace(
      Sessionbuf(modeS.hist.session, { scrollable = true }))
end



return Review

