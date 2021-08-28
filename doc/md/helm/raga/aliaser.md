# alias

Helper for setting up keyboard shortcuts in ragas.


For convenience--since we expect to have many uses in a row for the
same raga--we implement this as a closure generator which returns
the actual alias function, specific to a particular raga.


Also for convenience, we combine the function and shortcuts into a
single table, with the function in the [1] position, like:

```lua-example
alias { function() ... end
   NAV   = {"DOWN", "SHIFT_DOWN"},
   ASCII = {"e", "j"},
   ... }
```
```lua
local function aliaser(raga)
   local function alias(dict)
      local fn = dict[1]
      for category, values in pairs(dict) do
         if category ~= 1 then
            for _, value in ipairs(values) do
               raga[category][value] = fn
            end
         end
      end
   end
   return alias
end

return aliaser
```
