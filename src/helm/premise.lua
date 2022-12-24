


















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
      if premise.status == "accept" then
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










local insert, remove = assert(table.insert), assert(table.remove)
function Premise.validStatuses(premise)
   if premise:getLine() == "" then
      return { "insert" }
   end
   local answer = { "ignore", "accept", "watch", "trash" }
   -- "ignore" not valid for error responses
   if premise:isError() then
      remove(answer, 1)
   end
   -- premise.same will be nil until we have a result to compare
   if premise.new_round and not premise.same then
      if premise.status == "accept" then
         insert(answer, 3, "fail")
      elseif premise.status == "watch" then
         insert(answer, 4, "report")
      end
   end
   return answer
end











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

