




































































assert(meta)

local Txtbuf = require "txtbuf"

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










local function _paintResults(modeS, results, new)
   local rainbuf = {}
   local write = modeS.zones.write
   modeS:clearResults()
   local row = new and modeS.repl_top or modeS:replLine()
   modeS:writeResults(a.rc(row, modeS.l_margin))
   for i = 1, results.n do
      if results.frozen then
         rainbuf[i] = results[i]
      else
         local catch_val = ts(results[i])
         if type(catch_val) == 'string' then
            rainbuf[i] = catch_val
         else
            error("ts returned a " .. type(catch_val) .. "in printResults")
         end
      end
   end
   modeS:writeResults(concat(rainbuf, '   '))
   write(a.cursor.show())
end





local lines = assert(string.lines, "string.lines must be provided")

local function _writeLines(write, zone, str)
   local nl = a.col(zone.tc) .. a.jump.down(1)
   local pr_row = zone.tr
   for line in lines(str) do
       write(line)
       write(nl)
       pr_row = pr_row + 1
       if pr_row > zone.br then
          break
       end
   end
end





local concat = assert(table.concat)

local function _renderTxtbuf(modeS, zone, write)
   local lb = modeS.lex(tostring(zone.contents))
   if type(lb) == "table" then
      lb = concat(lb)
   end
   write(a.colrow(zone.tc, zone.tr))
   _writeLines(write, zone, lb)
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

function Zoneherd.paint(zoneherd, modeS)
   local write = zoneherd.write
   write(a.cursor.stash())
   write(a.cursor.hide())
   for i, zone in ipairs(zoneherd) do
      if zone.touched then
         -- erase
         write(a.erase._box( zone.tc,
                                zone.tr,
                                zone.bc,
                                zone.br ))
         write(a.colrow(zone.tc, zone.tr))
         -- actually render ze contents
         if type(zone.contents) == "string" then
            zoneherd.write(zone.contents)
         elseif type(zone.contents) == "table"
            and zone.contents.idEst == Txtbuf then
            _renderTxtbuf(modeS, zone, write)
         end
         zone.touched = false
      end
   end
   zoneherd.write(a.cursor.pop())
   zoneherd.write(a.cursor.show())
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













local function _zoneOffset(modeS)
   if modeS.max_col <= 80 then
      return 20
   elseif modeS.max_col <= 100 then
      return 30
   elseif modeS.max_col <= 120 then
      return 40
   else
      return 50
   end
end

local function new(modeS, writer)
   local zoneherd = meta(Zoneherd)
   local right_col = modeS.max_col - _zoneOffset(modeS)
   zoneherd.write = writer
   -- make Zones
   -- (top_col, top_row, bottom_col, bottom_row, z, debug-mark)
   zoneherd.status  = newZone( 1, 1, right_col, 1, 1, ".")
   zoneherd[1] = zoneherd.status
   zoneherd.command = newZone( modeS.l_margin,
                               modeS.repl_top,
                               right_col,
                               modeS:replLine(),
                               1, "|" )
   zoneherd[3] = zoneherd.command
   zoneherd.prompt  = newZone( 1,
                               modeS.repl_top,
                               modeS.l_margin - 1,
                               modeS.repl_top,
                               1, ">" )
   zoneherd[2] = zoneherd.prompt
   zoneherd.results = newZone( modeS.l_margin,
                               modeS:replLine() + 1,
                               right_col,
                               modeS.max_row,
                               1, "~" )
   zoneherd[4] = zoneherd.results
   zoneherd.stat_col = newZone( right_col + 1,
                                1,
                                modeS.max_col,
                                1,
                                1, "!" )
   zoneherd[5] = zoneherd.stat_col
   zoneherd.suggest = newZone( right_col + 1,
                               3,
                               modeS.max_col,
                               modeS.max_row,
                               1, "%" )
   zoneherd[6] = zoneherd.suggest
   return zoneherd
end



return new
