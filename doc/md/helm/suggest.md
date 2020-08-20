# Suggest

This is our autocomplete module\.

## Dependencies

```lua

local Lex = require "helm/lex"
local SelectionList = require "helm/selection_list"
local Rainbuf = require "helm/rainbuf"
local names = require "repr:repr/names"
local concat, insert, sort = assert(table.concat),
                             assert(table.insert),
                             assert(table.sort)
local c = import("singletons/color", "color")

```

```lua

local Suggest = meta {}
local new

```

### \_cursorContext\(modeS\)

Examines the text before the cursor to determine \(a\) what token we are in the
middle of, and \(b\) what if any path from the global environment we should
follow to determine a list of keys to complete from\. Answers nil if the token
we are in the middle of is not a symbol, and a nil second return value if the
path cannot be determined\.

```lua
local function _cursorContext(modeS)
   local lex_tokens = {}
   -- Ignore whitespace and comments
   for _, token in ipairs(modeS.lex(modeS.txtbuf)) do
      if token.color ~= c.no_color and token.color ~= c.comment then
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
   -- #todo once we're using =palette=, we'll be able to check the name
   -- of the color rather than needing the color table ourselves
   if not context or context.color ~= c.field then
      -- We're in a non-completable token
      return nil
   end
   -- Work backwards from there to determine the dotted path, if any,
   -- that we are completing within
   local path = {}
   local expect_sym = false
   index = index - 1
   while index > 0 do
      local path_token = lex_tokens[index]
      if expect_sym then
         if path_token.color == c.field
            insert(path, 1, tostring(path_token))
         else
            -- After a function call or [] subscript, we can't safely retrieve
            -- a table to complete against. A non-operator token is either a
            -- function call with a single string arg (this also most likely
            -- applies to a closing table brace), or an error.
            -- In all such cases, we want to complete against the full list
            -- of possible symbols.
            if tostring(path_token) == ")"
               or tostring(path_token) == "]"
               or tostring(path_token) == "}"
               or path_token.color ~= c.operator then
               path = nil
            end
            break
         end
      else
         -- Expected a . or :, got absolutely anything else, we've finished
         -- this dotted path.
         if path_token.color ~= c.operator
            or (tostring(path_token) ~= "."
            and tostring(path_token) ~= ":") then
            break
         end
      end
      expect_sym = not expect_sym
      index = index - 1
   end
   return context, path
end
```

### update\(modeS, category, value\)

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

local isidentifier = import("core/string", "isidentifier")
local hasmetamethod = import("core/meta", "hasmetamethod")
local hasfield = import("core:core/table", "hasfield")
local fuzz_patt = require "helm:helm/fuzz_patt"

function Suggest.update(suggest, modeS)
   local context, path = _cursorContext(modeS)
   if context == nil then
      suggest:cancel(modeS)
      return
   end

   -- First, build a list of candidate symbols--those that would be valid
   -- in the current position.
   local candidate_symbols, complete_against
   if path then
      complete_against = __G
      for _, key in ipairs(path) do
         complete_against = hasfield(complete_against, key)
      end
      -- If what we end up with isn't a table, we can't complete against it
      if type(complete_against) ~= "table" then
         complete_against = nil
      end
   end
   if complete_against ~= nil then
      candidate_symbols = {}
      repeat
         for k, _ in pairs(complete_against) do
            if isidentifier(k) then
               candidate_symbols[k] = true
            end
         end
         local index_table = hasmetamethod("__index", complete_against)
         -- Ignore __index functions, no way to know what they might handle
         complete_against = type(index_table) == "table" and index_table or nil
      until complete_against == nil
   -- Either no path was provided, or some part of it doesn't
   -- actually exist, fall back to completing against all symbols
   else
      candidate_symbols = names.all_symbols
   end

   -- Now we can actually filter those candidates for whether they match or not
   local suggestions = SelectionList()
   suggestions.best = true
   suggestions.frag = tostring(context):sub(1, context.cursor_offset)
   suggestions.lit_frag = suggestions.frag
   local match_patt = fuzz_patt(suggestions.frag)
   local matches = {}
   for sym in pairs(candidate_symbols) do
      local score = match_patt:match(sym)
      if score then
         insert(matches, { score = score, sym = sym })
      end
   end
   if #matches == 0 then
      suggest:cancel(modeS)
      return
   end
   sort(matches, _suggest_sort)
   for _, match in ipairs(matches) do
      insert(suggestions, match.sym)
   end
   if modeS.raga.name == "complete" then
      suggestions.selected_index = 1
   end
   suggestions = Rainbuf { [1] = suggestions, n = 1,
                               live = true, made_in = "suggest.update" }
   suggest.active_suggestions = suggestions
   modeS.zones.suggest:replace(suggestions)
end

```

### cancel\(\)

```lua
function Suggest.cancel(suggest, modeS)
   suggest.active_suggestions = nil
   modeS.zones.suggest:replace("")
end
```

### accept\(\)

```lua
function Suggest.accept(suggest, modeS)
   local suggestion = suggest.active_suggestions[1]:selectedItem()
   local context = _cursorContext(modeS)
   modeS.txtbuf:right(context.total_disp - context.cursor_offset)
   modeS.txtbuf:killBackward(context.total_disp)
   modeS.txtbuf:paste(suggestion)
end
```

### new\(\)

```lua

new = function()
   local suggest = meta(Suggest)
   return suggest
end

```

```lua
Suggest.idEst = new
return new
```
