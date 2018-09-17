






































































assert(meta)
local Zone = meta {}

local Zoneherd = meta {}








local function newZone(tr, tc, br, bc, z, debug_mark)
   local zone = meta(Zone)
   zone.tr = tr
   zone.tc = tc
   zone.br = br
   zone.bc = bc
   zone.z = z
   zone.debug_mark = debug_mark
   return zone
end





function Zoneherd:newZone(zoneherd, name, tr, tc, br, bc, z, debug_mark)
   zoneherd[name] = newZone(tr, tc, br, bc, z, debug_mark)
   -- this doesn't account for Z axis but for now:
   zoneherd[#zoneherd + 1] = zoneherd[name]
   return zoneherd
end










local function new(modeS, writer)
   local zoneherd = meta(Zoneherd)
   zoneherd.write = writer
   -- make Zones
   -- (top_row, top_col, bottom_row, bottom_col, z, debug-mark)
   zoneherd.command = newZone(2, modeS.l_margin, 80, 2, 0, "|")
   zoneherd[1] = zoneherd.command
   zoneherd.results = newZone(modeS:replLine() + 1,
                              modeS.l_margin, 80, 30, 0, "~")
   zoneherd[2] = zoneherd.results
   return zoneherd
end



return new
