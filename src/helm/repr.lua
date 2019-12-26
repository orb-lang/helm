















local C = require "singletons/color"
local Composer = require "helm/repr/composer"
local tabulate = require "helm/repr/tabulate"

local concat = assert(table.concat)







local repr = {}










function repr.lineGen(tab, disp_width, color)
   color = color or C.color
   local generator = Composer(tabulate)
   return generator(tab, disp_width, color)
end

function repr.lineGenBW(tab, disp_width)
   return repr.lineGen(tab, disp_width, C.no_color)
end












function repr.ts(val, disp_width, color)
   local phrase = {}
   for line in repr.lineGen(val, disp_width, color or C.no_color) do
      phrase[#phrase + 1] = line
   end
   return concat(phrase, "\n")
end









function repr.ts_color(val, disp_width, color)
   return repr.ts(val, disp_width, color or C.color)
end



return repr
