






































































assert(meta)
local Zone = meta {}

local Zoneherd = meta {}













function _inside(col, row, zone)
   return (col >= zone.tc)
     and  (col <= zone.bc)
     and  (row >= zone.tr)
     and  (row <= zone.br)
end

function _collide(z_a, z_b)
   if z_a.z ~= z_b.z then
      -- this is just 'false' but let's refactor that when it's time
      return {false, false, false, false}, false, {false, false}
   end

   local collision = false
   -- clockwise from top left
   local z_a_corners = { {z_a.tc, z_a.tr},
                         {z_a.bc, z_a.tr},
                         {z_a.bc, z_a.br},
                         {z_a.tc, z_a.br} }
   local hits = {}
   for i, corner in ipairs(z_a_corners) do
      local hit = _inside(corner[1], corner[2], z_b)
      if hit then
         collision = true
      end
      hits[i] = hit
   end
   local a_left_of_b = z_a.tc < z_b.tc
   local a_above_b = z_a.tr < z_b.tr
   -- bottom of a over top of b
   if (hits[3] or hits[4]) and a_above_b then
      z_b.tr = z_a.br + 1
   end
   -- right of a over left of b
   if (hits[2] or hits[3]) and a_left_of_b then
      z_b.tc = z_a.bc + 1
   end
   -- top of a over bottom of b
   if (hits[1] or hits[2]) and not a_above_b then
      z_b.br = z_a.tr - 1
   end
   -- left of a over right of b
   if (hits[1] or hits[4]) and not a_left_of_b then
      z_b.bc = z_a.tc - 1
   end
   return hits, collision, {a_left_of_b, a_above_b}
end










local function _collideAll(zoneherd, zone)
   for i, z in ipairs(zoneherd) do
      if zone ~= z then
         _collide(zone, z)
      end
   end
end








function Zone.height(zone)
   return zone.br - zone.tr + 1
end

function Zone.width(zone)
   return zone.bc - zone.tc + 1
end






function Zone.replace(zone, rainbuf)
   zone.contents = rainbuf
   zone.touched = true

   return zone
end










function Zoneherd.newZone(zoneherd, name, tc, tr, bc, br, z, debug_mark)
   zoneherd[name] = newZone(tc, tr, bc, br, z, debug_mark)
   -- this doesn't account for Z axis but for now:
   zoneherd[#zoneherd + 1] = zoneherd[name]
   -- todo: make a Zoneherd:add(zone, name) that handles z-ordering
   -- and auto-adjusts proportionally.
   return zoneherd
end


















function Zoneherd.adjust(zoneherd, zone, delta, bottom)
   if not bottom then
      zone.tc = zone.tc + delta[1]
      zone.tr = zone.tr + delta[1]
   else
      zone.bc = zone.bc + delta[1]
      zone.br = zone.br + delta[2]
   end

   _collideAll(zoneherd, zone)
   return zoneherd
end










local a = require "anterm"

function Zoneherd.paint(zoneherd)
   zoneherd.write(a.cursor.hide())
   for i, zone in ipairs(zoneherd) do
      -- if zone.touched then
      --
      -- #todo remove the dash once box is refactored
      zoneherd.write(a.erase._box( zone.tc,
                                   zone.tr,
                                   zone.bc,
                                   zone.br,
                                   zone.debug_mark ))
      -- actually render ze contents
      -- zone.touched = false
   end
   zoneherd.write(a.cursor.show())
   zoneherd.painted = true -- just to fuck wit, #remove
   return zoneherd
end








local function newZone(tc, tr, bc, br, z, debug_mark)
   assert(tc <= bc, "tc: " .. tc .. ", bc: " .. bc)
   assert(tr <= br, "tr: " .. tr .. ", br: " .. br)
   local zone = meta(Zone)
   zone.tc = tc
   zone.tr = tr
   zone.bc = bc
   zone.br = br
   zone.z = z
   zone.debug_mark = debug_mark
   zone.touched = false
   -- zone.contents, a rainbuf, is provided later
   return zone
end










local function new(modeS, writer)
   local zoneherd = meta(Zoneherd)
   zoneherd.write = writer
   -- make Zones
   -- (top_col, top_row, bottom_col, bottom_row, z, debug-mark)
   zoneherd.command = newZone( modeS.l_margin,
                               modeS.repl_top,
                               modeS.max_col - 20,
                               modeS:replLine(),
                               0, "|")
   zoneherd[1] = zoneherd.command
   zoneherd.results = newZone( modeS.l_margin,
                               modeS:replLine() + 1,
                               modeS.max_col - 20,
                               modeS.max_row,
                               0, "~")
   zoneherd[2] = zoneherd.results
   zoneherd.stat_col = newZone( modeS.max_col - 19,
                                1,
                                modeS.max_col,
                                1,
                                0, "!")
   zoneherd[3] = zoneherd.stat_col
   zoneherd.suggest = newZone( modeS.max_col - 19,
                               3,
                               modeS.max_col,
                               modeS.max_row,
                               0, "%")
   zoneherd[4] = zoneherd.suggest
   return zoneherd
end



return new
