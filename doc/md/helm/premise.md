# Premise

A Premise is a view over a round, with the addition of a status \(accept,
reject, ignore, etc, exact valid values vary by context\) and possibly a title\.
It may be worth separating run\-review premises \(with one set of valid status
values and no title\) from session premises \(with a different set of statuses
and a title\), but we'll start with leaving that behavior in the relevant
Agent\.

This means that the premise behaves as though it has the round itself in
\`\_\_index\`, in addition to its own cassette of methods\. Assignments to fields
of the premise shadow the values from the round rather than modifying them,
but we provide methods to modify the round if needed\. This is related to
`Self`\-style prototype inheritance, though the analogy is probably not exact\.

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
`Premise:asRound(data)`\.

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


### Premise:asRound\(\)

Convert the premise back to a round, which shares no state with the premise or
the round it is viewing/wrapping\. In practice this means starting from scratch
with just the line, but note that we copy the line from ourselves, not our
underlying round, in case it has been shadowed\.

```lua
local Round
function Premise.asRound(premise)
   Round = Round or require "helm:round"
   return Round(premise.line)
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