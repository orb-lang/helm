






































































assert(meta)
local Zone = meta {}

local Zoneherd = meta {}








local function newZone(tc, tr, bc, br, z, debug_mark)
   local zone = meta(Zone)
   zone.tc = tc
   zone.tr = tr
   zone.bc = bc
   zone.br = br
   zone.z = z
   zone.debug_mark = debug_mark
   return zone
end














local function _inside(col, row, zone)
   return (col >= zone.tc)
      and (col <= zone.bc)
      and (row >= zone.tr)
      and (row <= zone.br)
end

function _collide(z_a, z_b)
   local z_a_corners = { {z_a.tc, z_a.tr},
                         {z_a.tc, z_a.br},
                         {z_a.bc, z_a.tr},
                         {z_a.bc, z_a.br} }
   local hits = {}
   for i, corner in ipairs(z_a_corners) do
      hits[i] = _inside(corner[1], corner[2], z_b)
   end
   return hits
end







function Zoneherd:newZone(zoneherd, name, tc, tr, bc, br, z, debug_mark)
   zoneherd[name] = newZone(tc, tr, bc, br, z, debug_mark)
   -- this doesn't account for Z axis but for now:
   zoneherd[#zoneherd + 1] = zoneherd[name]
   -- todo: make a Zoneherd:add(zone, name) that handles z-ordering
   -- and auto-adjusts proportionally.
   return zoneherd
end






















local function new(modeS, writer)
   local zoneherd = meta(Zoneherd)
   zoneherd.write = writer
   -- make Zones
   -- (top_col, top_row, bottom_col, bottom_row, z, debug-mark)
   zoneherd.command = newZone(modeS.l_margin,     modeS:replLine(),
                              modeS.max_col - 20, 2,
                              0, "|")
   zoneherd[1] = zoneherd.command
   zoneherd.results = newZone(modeS.l_margin,     modeS:replLine(),
                              modeS.max_col - 20, modeS.max_row,
                              0, "~")
   zoneherd[2] = zoneherd.results
   return zoneherd
end



return new
