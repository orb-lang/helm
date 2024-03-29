# Suggest Agent

  This is our autocomplete module\.


#### imports

```lua
local SelectionList = require "helm:selection_list"
local names = require "repr:names"
local insert, sort = assert(table.insert), assert(table.sort)
```


```lua
local meta = assert(require "core:cluster" . Meta)
local ResultListAgent = require "helm:agent/result-list"
local SuggestAgent = meta(getmetatable(ResultListAgent))
```


### SuggestAgent:cursorContext\(\)

  Examines the text before the cursor to determine \(a\) what token we are in
the middle of, and \(b\) what if any path from the global environment we should
follow to determine a list of keys to complete from\. Answers `nil` if the
token we are in the middle of is not a symbol, and a `nil` second return value
if the path cannot be determined\.

```lua
function SuggestAgent.cursorContext(suggest)
   local lex_tokens = {}
   -- Ignore whitespace and comments
   for _, token in ipairs(suggest:agentMessage("edit", "tokens")) do
      if token.color ~= "no_color" and token.color ~= "comment" then
         insert(lex_tokens, token)
      end
   end
   -- Find the index of the token containing the cursor
   local index, context
   for i, token in ipairs(lex_tokens) do
      if token.cursor_offset then
         index = i
         context = token
         break
      end
   end
   if not context or context.color ~= "field" then
      -- We're in a non-completable token
      return nil
   end
   -- Work backwards from there to determine the dotted path, if any,
   -- that we are completing within
   local path = {}
   local expect_field = false
   index = index - 1
   while index > 0 do
      local path_token = lex_tokens[index]
      if expect_field then
         if path_token.color == "field" then
            insert(path, 1, tostring(path_token))
         else
            -- If we expected an identifier/field and got something else,
            -- we're likely in a situation like foo[bar].baz, having just
            -- examined the dot. If the content of the braces is a literal,
            -- we *could* deal with it anyway, but this is not yet implemented.
            path = nil
            break
         end
      elseif not tostring(path_token):find("^[.:]$") then
         -- Expected a . or :, got absolutely anything else, we've finished
         -- this dotted path.
         break
      end
      expect_field = not expect_field
      index = index - 1
   end
   return context, path
end
```


### SuggestAgent:update\(\)

Updates the completion list based on the current contents of the Txtbuf\.

```lua
local function _suggest_sort(a, b)
   if a.score ~= b.score then
      return a.score < b.score
   elseif #a.sym ~= #b.sym then
      return #a.sym < #b.sym
   else
      return a.sym < b.sym
   end
end

local isidentifier = import("core:string", "isidentifier")
local hasmetamethod = import("core:meta", "hasmetamethod")
local safeget = import("core:table", "safeget")
local fuzz_patt = require "helm:fuzz_patt"
local Set = require "set:set"

local function _candidates_from(complete_against)
   -- Either no path was provided, or some part of it doesn't
   -- actually exist, fall back to completing against all symbols
   if complete_against == nil then
      return names.all_symbols
   end
   local count = 0
   local candidate_symbols = Set()
   repeat
      -- Do not invoke any __pairs metamethod the table may have
      for k, _ in next, complete_against do
         if isidentifier(k) then
            count = count + 1
            candidate_symbols[k] = true
         if count > 500 then
               return candidate_symbols
            end
         end
      end
      local index_table = hasmetamethod("__index", complete_against)
      -- Ignore __index functions, no way to know what they might handle
      complete_against = type(index_table) == "table" and index_table or nil
   until complete_against == nil
   return candidate_symbols
end

local function _set_suggestions(suggest, suggestions)
   suggest.last_collection = suggestions
   suggest:contentsChanged()
end


function SuggestAgent.update(suggest)
   local context, path = suggest:cursorContext()
   if context == nil then
      return _set_suggestions(suggest, nil)
   end

   -- First, build a list of candidate symbols--those that would be valid
   -- in the current position.
   local complete_against
   if path then
      complete_against = modeS.eval.eval_env
      for _, key in ipairs(path) do
         complete_against = safeget(complete_against, key)
      end
      -- If what we end up with isn't a table, we can't complete against it
      if type(complete_against) ~= "table" then
         complete_against = nil
      end
   end
   local candidate_symbols = _candidates_from(complete_against)

   -- Now we can actually filter those candidates for whether they match or not
   local suggestions = SelectionList(tostring(context)
                                       :sub(1, context.cursor_offset))
   local match_patt = fuzz_patt(suggestions.frag)
   local matches = {}
   for sym in pairs(candidate_symbols) do
      local score = match_patt:match(sym)
      if score then
         insert(matches, { score = score, sym = sym })
      end
   end
   if #matches == 0 then
      return _set_suggestions(suggest, nil)
   end
   sort(matches, _suggest_sort)
   for _, match in ipairs(matches) do
      insert(suggestions, match.sym)
   end
   _set_suggestions(suggest, suggestions)
end
```


### Keymaps and Event Handlers


### SuggestAgent:acceptSelected\(\)


```lua
function SuggestAgent.acceptSelected(agent)
   local suggestion = agent:selectedItem()
   agent:quit()
   if suggestion then
      agent:agentMessage("edit", "replaceToken", suggestion)
      return true
   else
      return false
   end
end
```


#### SuggestAgent:userCancel\(\)

We just unconditionally quit when ESC is pressed\.

```lua
SuggestAgent.userCancel = SuggestAgent.quit
```


#### SuggestAgent:activateCompletion\(\)

Event\-handler function that activates completion if suggestions are available,
falling through to the next command if not\.

```lua
function SuggestAgent.activateCompletion(agent)
   if agent.last_collection then
      agent:selectFirst()
      agent:shiftMode("complete")
      return true
   else
      return false
   end
end
```


#### Keymaps

```lua
SuggestAgent.keymap_try_activate = {
   TAB = "activateCompletion",
   ["S-TAB"] = "activateCompletion",
}

function SuggestAgent.acceptAndFallthrough(agent)
   agent:acceptSelected()
   return false
end
function SuggestAgent.quitAndFallthrough(agent)
   agent:quit()
   return false
end
local find = assert(string.find)
function SuggestAgent.acceptOnNonWordChar(agent, event)
   if find(event.key, "[^a-zA-Z0-9_]") then
      agent:acceptSelected()
   end
   return false
end

local addall = assert(require "core:table" . addall)
SuggestAgent.keymap_actions = {
   LEFT            = "acceptAndFallthrough",
   PASTE           = "quitAndFallthrough",
   ["[CHARACTER]"] = { method = "acceptOnNonWordChar", n = 1 }
}
addall(SuggestAgent.keymap_actions, ResultListAgent.keymap_actions)
```


```lua
local constructor = assert(require "core:cluster" . constructor)
return constructor(SuggestAgent)
```
