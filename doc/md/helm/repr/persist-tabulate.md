# Persist Tabulator


  This tabulator takes a result, and produces a string compatible with our
database representation format\.

```lua
local function ninsert(tab, val)
   tab.n = tab.n + 1
   tab[tab.n] = val
end

local SOH, STX = "\x01", "\x02"

local function dump_token(token, stream)
   ninsert(stream, SOH)
   if token.event then
      ninsert(stream, "event=")
      ninsert(stream, token.event)
   end
   if token.wrappable then
      if token.event then ninsert(stream, " ") end
      ninsert(stream, "wrappable")
   end
   ninsert(stream, STX)
   ninsert(stream, tostring(token))
   return stream
end

local tabulate = require "helm/repr/tabulate"
```


### tab\_callback

This returns a tabulator callback, which will process 100 tokens at a time,
and eventually, return the resultant strings\.

Takes two arguments: `results_tabulate` contains prepared iterators over a
results table, and `results_tostring` is the container for the stringified
results\.

Returns a function which will return `false` until complete, when it returns
`true, results_tostring`\.

```lua
local concat = assert(table.concat)

local function tab_callback(results_tabulates, results_tostring)
   local i = 1
   return function()
      if i > #results_tabulates then
         return true, results_tostring
      end
      local start_token_count = results_tostring[i].n
      if start_token_count > 15000 then
         -- bail early
         results_tostring[i] = concat(results_tostring[i])
         i  = i + 1
         return false
      end
      while results_tostring[i].n - start_token_count <= 100 do
         local success, token = pcall(results_tabulates[i])
         if success then
            if token then
               dump_token(token, results_tostring[i])
            else
               results_tostring[i] = concat(results_tostring[i])
               i = i + 1
               return false
            end
         else
            error(token)
         end
      end
      return false
   end
end
```

```lua
return tab_callback
```
