

























local cluster = require "cluster:cluster"
local helm_db = require "helm:helm-db"

local core = require "qor:core"
local table = core.table

local s = require "status:status" ()




local new, Round = cluster.order()






function Round.isBlank(round)
  return round.line == ""
end












function Round.results(round)
  if type(round.response[1]) == "table" then
    if round.response[1].error then
      -- Error is not a proper result
      return nil
    else
      return round.response[1]
    end
  elseif round.db_result then
    return round.db_result
  else
    return nil
  end
end












local clone = assert(table.clone)
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

