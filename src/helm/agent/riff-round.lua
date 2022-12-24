







local cluster = require "cluster:cluster"
local Agent = require "helm:agent/agent"






local new, RiffRoundAgent = cluster.genus(Agent)
cluster.extendbuilder(new, true)




return new

