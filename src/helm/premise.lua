

















local cluster = require "cluster:cluster"



local new, Premise, Premise_M = cluster.order()











cluster.construct(new, function(_new, premise, round, cfg)
   -- Store the round in this special slot to keep it out of the way
   -- of any possible string-keyed fields
   premise[premise] = round
   for k, v in pairs(cfg) do
      premise[k] = v
   end
   return premise
end)











function Premise.asRound(premise)
   return premise[premise]
end









function Premise_M.__index(premise, key)
   if Premise[key] ~= nil then
      return Premise[key]
   else
      return premise[premise][key]
   end
end




return new

