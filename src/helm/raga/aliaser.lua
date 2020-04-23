



















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
