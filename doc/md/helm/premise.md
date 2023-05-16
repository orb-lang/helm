# Premise

A Premise is a view over a round, with the addition of a status \(accept,
watch, ignore, etc, exact valid values vary by context\) and possibly a title\.

This means that the premise behaves as though it has the round itself in
\`\_\_index\`, in addition to its own cassette of methods\. \(This is related to
`Self`\-style prototype inheritance, though the analogy is probably not exact\.\)
Assignments to fields of the premise shadow the values from the round rather
than modifying them\. This is intentional\-\-if a Round is needed, we provide
`:asRound` to convert back to one\.

#### imports

```lua
local cluster = require "cluster:cluster"
```

```lua
local new, Premise, Premise_M = cluster.order()
```


### Premise\(round, data\)

Constructs a premise wrapping `round`, with title and status from `data`\.

This is essentially private, with the public API being
`Round:asPremise(data)`\.

```lua
cluster.construct(new, function(_new, premise, round, data)
   -- Store the round in this special slot to keep it out of the way
   -- of any possible string-keyed fields
   premise[premise] = round
   premise.status = data.status
   premise.title = data.title
   return premise
end)
```


### Premise:validStatuses\(\)

Answers the list of statuses this premise could be in\. This consists of a
fixed list in most cases, but empty lines must always be "insert", and if
results differ, we introduce a corresponding special status to display this\.

```lua
local insert = assert(table.insert)
function Premise.validStatuses(premise)
   if premise:isBlank() then
      return { "insert" }
   end
   local answer = { "ignore", "accept", "watch", "trash" }
   -- premise.same will be nil until we have a result to compare
   if premise.new_round and not premise.same then
      if premise.status() == "accept" then
         insert(answer, 2, "fail") -- before 'accept'
      elseif premise.status() == "watch" then
         insert(answer, 3, "report") -- before 'watch'
      end
   end
   -- "ignore" replaced by "warn" for error responses
   if premise:isError() then
      answer[1] = "warn"
   end
   return answer
end
```


### Premise:asRound\(\)

Convert the premise back to a round, which shares no state with the premise or
the round it is viewing/wrapping\. In practice this means starting from scratch
with just the line, but note that we copy the line from ourselves, not our
underlying round, in case it has been shadowed\.

```lua
local Round
function Premise.asRound(premise)
   Round = Round or require "helm:round"
   return Round(premise:getLine())
end
```


### Premise:compareToNewEvaluation\(new\_round\)

Examine `round`, which is a newer evaluation of the premise \(always the same
line as premise\.line, may or may not be the same as the underlying round's
line\), and determine whether the response differs \(this is cached\) in order to
update the status and valid statuses\.

```lua
local function _isSame(old_response, new_response)
   -- Was an error, now a result or vice-versa
   if old_response.error ~= new_response.error
   -- Results are different lengths
   or old_response.n ~= new_response.n then
      return false
   end
   for i, old_res in ipairs(old_response) do
      local new_res = new_response[i]
      if old_res ~= new_res then
         return false
      end
   end
   return true
end

function Premise.compareToNewEvaluation(premise, new_round)
   premise.new_round = new_round
   -- Comparison operates on the DB/stringified responses
   premise.same = _isSame(premise.db_response, new_round.db_response)
   if not premise.same then
      if premise.status() == "accept" then
         premise.status = "fail"
      elseif premise.status == "watch" then
         premise.status = "report"
      end
   end
   -- An error on an ignored premise counts as a failure
   -- Usually this will lead to knock-on failures down the line,
   -- but those aren't the real problem--this makes it easier to diagnose
   if premise.status == "ignore" and new_round.response.error then
      premise.status = "warn"
   end

   -- Copy the live response for viewing as well as the DB response
   premise.response = new_round.response
   premise.db_response = new_round.db_response
end
```


### Premise\.\_\_index

We search our own cassette before the round, and in any case to search both,
we need a function\.

```lua
function Premise_M.__index(premise, key)
   if Premise[key] ~= nil then
      return Premise[key]
   else
      return premise[premise][key]
   end
end
```


```lua
return new
```