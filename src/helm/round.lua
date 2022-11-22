



























local core = require "qor:core"
local table = core.table

local cluster = require "cluster:cluster"




local new, Round = cluster.order()











function Round.getLine(round)
  return round.line
end

function Round.setLine(round, new_line)
  round.line = new_line
  -- round.id = nil
end






function Round.isBlank(round)
  return round:getLine() == ""
end










local count = assert(core.string.count)
function Round.lineCount(round)
  return count(round:getLine(), '\n') + 1
end






function Round.getResponse(round)
  return round.response[1]
end

function Round.setResponse(round, new_response)
  round.response[1] = new_response
  -- round.id = nil
end

function Round.setDBResponse(round, db_response)
  round.db_response = db_response
  local existing = round:getResponse()
  -- Don't overwrite live result with DB result
  if type(existing) ~= "table" then
    round:setResponse(db_response)
  end
end

















function Round.result(round)
  local response = round:getResponse()
  if not response or type(response) ~= "table" or response.error then
    -- Error or status string ('new', 'unloaded', etc) is not a result
    return nil
  else
    return response
  end
end









function Round.hasResults(round)
  local result = round:result()
  return result and result.n > 0
end








function Round.isError(round)
  local response = round:getResponse()
  return response and type(response) == "table" and response.error
end









function Round.newFromLine(round)
  return new(round:getLine())
end














function Round.asRound(round)
  return round
end









local Premise
function Round.asPremise(round, data)
  Premise = Premise or require "helm:premise"
  return Premise(round, data)
end












cluster.construct(new, function(_new, round, line_or_data, response)
  if type(line_or_data) == "table" then
    assert(response == nil,
      "Supply only one argument when constructing a Round from a table")
    assert(line_or_data.line,
      "Must supply a line when constructing a Round from a table")
    round.line = line_or_data.line
    round.line_id = line_or_data.line_id
    -- #todo What should this value be? We don't know without actually loading
    -- the response whether it is a success or error, and this constructor may
    -- end up with other uses than just loading from the DB, though I'm not
    -- sure what.
    round.response = { 'unloaded' }
  else
    round.line = line_or_data or ''
    round.response = { response or 'new' }
  end
  return round
end)




return new

