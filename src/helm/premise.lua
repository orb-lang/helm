

















local cluster = require "cluster:cluster"



local new, Premise, Premise_M = cluster.order()











cluster.construct(new, function(_new, premise, round, data)
   -- Store the round in this special slot to keep it out of the way
   -- of any possible string-keyed fields
   premise[premise] = round
   premise.status = data.status
   premise.title = data.title
   return premise
end)











local Round
function Premise.asRound(premise)
   Round = Round or require "helm:round"
   return Round(premise:getLine())
end









function Premise_M.__index(premise, key)
   if Premise[key] ~= nil then
      return Premise[key]
   else
      return premise[premise][key]
   end
end




return new

