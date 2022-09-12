# Round

A round represents a single line of input as entered at a particular time,
along with any results that may have been produced by evaluating it\.
Eventually a round's evaluation may be paused due to coroutine yield as well\.


## Instance fields


- input\_id \(currently line\_id\), if the round has been persisted\.

- line\_id \(once distinct from input\_id\)\. Lazily retrieved\.

- line \- the actual text of the input line\. Lazily retrieved, or may be set
  without an input\_id or line\_id for a new round that is being edited\.

- response: Single\-element array table whose value is either an in\-process
  status, like 'advance', or the results \(or later something to indicate
  "yielded these things, waiting for resume"\)\. The external interface to this
  will unwrap the table, but we need to allow \`valiant\` to update it in place\.

- db\_response: The response as it was persisted to the database\. Note this is
  not meant as the "old response" with `response` containing something
  different\-\- session re\-evaluation/diff will use two rounds per premise\-\-just
  that some places may need the result\-as\-frozen instead of the live table\.
  When a Round is rehydrated from the DB, this will be the only response
  available\.


#### imports

```lua
local cluster = require "cluster:cluster"
local helm_db = require "helm:helm-db"

local core = require "qor:core"
local table = core.table

local s = require "status:status" ()
```


```lua
local new, Round = cluster.order()
```


### Round:isBlank\(\)

```lua
function Round.isBlank(round)
  return round.line == ""
end
```


### Round:lineCount\(\)

Answer the number of actual lines in the round's `line`\. We treat newlines as
separators, i\.e\. a trailing newline means a trailing blank line, so this is
the number of newlines plus one\.

```lua
local count = assert(core.string.count)
function Round.lineCount(round)
  return count(round.line, '\n') + 1
end
```


### Round:result\(\)

Retrieves the result \(of evaluation\) for the round, preferring live results if available
but falling back to database results if not\.

A result is a list of zero\-or\-more return values from successful evaluation\.
We refer to it as a unit with the singular, "result"\. "Results", plural,
refers to the individual values, and as such, a round can "have a result", but
also "not have results", in the case of `n = 0`\.

\#todo
separate responsibility with Historian and/or the Deck\.

```lua
function Round.result(round)
  local response
  if type(round.response[1]) == "table" then
    response = round.response[1]
  elseif round.db_response then
    response = round.db_response
  end
  if response and response.error then
    -- Error is not a result
    return nil
  else
    return response
  end
end
```


### Round:hasResults\(\)

Answer whether the round has **at least one** result\. See `:result()`
above\-\-this is an additional condition beyond just `:result() ~= nil`\.

```lua
function Round.hasResults(round)
  return round:result() and round:result().n > 0
end
```


### Round\(\[line\[, response\]\), Round\(data\)

Construct a Round from the provided line and optional response; or from a
table containing \(at least\) the field `line`\. The response should be supplied
without a wrapping table as this is an internal implementation detail\. In the
table case, we copy only those fields that are valid for a Round \(currently
just `line` and `line_id`, but this will become more complex as of schema 7\)\.

```lua
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
```


```lua
return new
```