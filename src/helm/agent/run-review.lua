








local core = require "qor:core"
local table = core.table

local cluster = require "cluster:cluster"
local ReviewAgent = require "helm:agent/review"

local Round = require "helm:round"






local new, RunReviewAgent = cluster.genus(ReviewAgent)
cluster.extendbuilder(new, true)









local insert = assert(table.insert)
function RunReviewAgent.setInitialSelection(agent)
   if #agent.topic == 0 then
      insert(agent.topic, Round():asRiffRound{ status = "insert" })
   end
   agent.selected_index = 1
end




RunReviewAgent.insert_after_status = "keep"








local Deque = require "deque:deque"
function RunReviewAgent.evalAndResume(agent)
   -- Clear out any insertion-in-progress
   agent:cancelInsertion()
   local to_run = Deque()
   for _, round in ipairs(agent.topic) do
      if round.status == "keep" then
         to_run:push(round:asRound())
      end
   end
   agent :send { to = "agents.status", method = "update", "default" }
   agent :send { method = "pushMode", "nerf" }
   agent :send { method = "rerun", to_run }
end




return new

