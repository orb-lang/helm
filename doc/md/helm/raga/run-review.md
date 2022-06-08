# Run review

Raga specialized for reviewing a Run, i\.e\. performing an interactive restart\.

```lua
local clone = assert(core.table.clone)
local Review = require "helm:raga/review"
```

```lua
local RunReview = clone(Review, 2)
RunReview.name = "run_review"
RunReview.prompt_char = "🟡"
RunReview.keymap = require "helm:keymap/run-review"
RunReview.target = "agents.run_review"
```


### RunReview\.onShift\(\)

```lua
function RunReview.onShift()
   -- #todo decide which form to display based on...what? Selection maybe,
   -- leave nothing selected at first? Gets pretty ugly doing this here
   -- in that case though...
   send { to = "agents.status", method = "update", "run_review_initial" }

   Review.onShift()
end
```

```lua
return RunReview
```