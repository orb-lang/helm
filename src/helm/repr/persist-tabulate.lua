






local C = require "singletons/color"

local tabulate = require "helm/repr/tabulate"



local persist_tabulate = {}



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

persist_tabulate.tab_callback = tab_callback








function persist_tabulate.tabulate(results)
   local results_tostring, results_tabulates = {}, {}
   -- Make a dummy table to stand in for Composer:window(),
   -- since we won't be making a Composer at all.
   local dummy_window = { width = 80, remains = 80, color = C.no_color }
   for i = 1, results.n do
      results_tabulates[i] = tabulate(results[i], dummy_window, C.no_color)
      results_tostring[i] = { n = 0 }
   end
   local persist_cb = tab_callback(results_tabulates, results_tostring)
   local done = false
   repeat
      done = persist_cb()
   until done
   return results_tostring
end



return persist_tabulate
