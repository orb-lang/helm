








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
      -- #todo this shouldn't be a Premise but some other Round specialization
      insert(agent.topic, Round():asPremise{ status = "insert" })
   end
   agent.selected_index = 1
end



















RunReviewAgent.valid_statuses = { "keep", "insert", "trash" }
RunReviewAgent.was_inserting = false












function RunReviewAgent.insertRound(agent)
   local round = Round():asPremise{ status = "insert" }
   insert(agent.topic, agent.selected_index, round)
   -- These agents are lazy-initialized, so we can
   -- just make room (with table stuffing)...
   insert(agent.edit_agents, agent.selected_index, false)
   -- ...and inform the buffer
   agent:bufferCommand("roundInserted", agent.selected_index)
   agent:_updateResultsAgent()
end











local remove = assert(table.remove)
function RunReviewAgent.cancelInsertion(agent)
   if agent:selectedRound().status ~= "insert"
      -- Don't remove an "insert" round if it's the very last one
      or #agent.topic == 1 then
         return
   end
   remove(agent.topic, agent.selected_index)
   remove(agent.edit_agents, agent.selected_index)
   agent:bufferCommand("roundRemoved", agent.selected_index)
   agent:_updateResultsAgent()
   agent.was_inserting = true
end









function RunReviewAgent.setSelectedState(agent, state)
   local round = agent:selectedRound()
   if round.status == state then return end
   -- Any status change clears the `was_inserting` flag, *except* canceling
   -- out of insertion, which sets it instead. Save it locally and clear it
   -- before deciding what to do, that way it can just be *re*-set in the
   -- one case that needs it.
   local was_inserting = agent.was_inserting
   agent.was_inserting = false
   if state == "insert" then
      if was_inserting then
         -- #todo this is dependent on only having two non-insert statuses,
         -- if there were more, we would need to know the intended
         -- cycle direction, so this would need to become an assertion failure
         -- and we would have to handle this in overrides of
         -- :[reverse]ToggleSelectedState
         state = round.status == "keep" and "trash" or "keep"
         ReviewAgent.setSelectedState(agent, state)
      else
         agent:insertRound()
      end
   else
      -- Need to explicitly check here because we don't want to change another
      -- round's status when canceling out of insertion. Setting the flag
      -- means the change will occur the *next* time tab is pressed
      if round.status == "insert" then
         agent:cancelInsertion()
      else
         ReviewAgent.setSelectedState(agent, state)
      end
   end
end











function RunReviewAgent.selectionChanged(agent)
   agent.was_inserting = false
   ReviewAgent.selectionChanged(agent)
end














function RunReviewAgent.selectIndex(agent, index)
   agent:cancelInsertion()
   ReviewAgent.selectIndex(agent, index)
end
function RunReviewAgent.selectNextWrap(agent)
   agent:cancelInsertion()
   ReviewAgent.selectNextWrap(agent)
end
function RunReviewAgent.selectPreviousWrap(agent)
   agent:cancelInsertion()
   ReviewAgent.selectPreviousWrap(agent)
end








function RunReviewAgent.editLine(agent)
   local line = agent:selectedRound().line
   agent :send { to = "agents.edit", method = "update", line }
   agent :send { method = "pushMode", "edit_line"}
end








function RunReviewAgent.cancelLineEdit(agent)
   agent:cancelInsertion()
   agent :send { to = "agents.edit", method = "clear" }
   agent :send { method = "popMode" }
end











function RunReviewAgent.acceptLineEdit(agent)
   local line = agent :send { to = "agents.edit", method = "contents" }
   agent :send { to = "agents.edit", method = "clear" }
   local round = agent:selectedRound()
   if line:find("^%s*$") then
      if round.status ~= "insert" then
         round.status = "trash"
      end
   else
      round.line = line
      -- Switch out the status without going through the usual channels
      -- so that we don't remove the newly-added round in the process
      if round.status == "insert" then
         round.status = "keep"
      end
      agent:_updateEditAgent(agent.selected_index)
      agent:selectNextWrap()
   end
   agent :send { method = "popMode" }
end








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

