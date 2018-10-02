




































































assert(meta)

local concat = assert(table.concat)

local Txtbuf = require "txtbuf"

local Rainbuf = require "rainbuf"

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





function Zone.set(zone, tc, tr, bc, br)
   zone.tc = tc
   zone.tr = tr
   zone.bc = bc
   zone.br = br
   return zone
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








local function _writeResults(write, zone, new)
   local rainbuf = {}
   local row = zone.tr
   local results = zone.contents
   if not results then
      return nil
   end
   if results.idEst ~= Rainbuf then
      results = Rainbuf(results)
   end
   local nl = a.col(zone.tc) .. a.jump.down(1)
   for line in results:lineGen(zone:height() + 1) do
      write(line)
      write(nl)
   end
end





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






function Zoneherd.adjustCommand(zoneherd)
   local lines = zoneherd.command.contents and zoneherd.command.contents.lines
   local txt_off = lines and #lines -1 or 0
   zoneherd.command.br = zoneherd.command.tr + txt_off
   zoneherd.results.tr = zoneherd.command.br + 1
   return zoneherd
end





function Zoneherd.reflow(zoneherd, modeS)
   local right_col = modeS.max_col - _zoneOffset(modeS)
   local txt_off = modeS.txtbuf and #modeS.txtbuf.lines - 1 or 0
   zoneherd.status:set(1, 1, right_col, 1)
   zoneherd.command:set( modeS.l_margin,
                         modeS.repl_top,
                         right_col,
                         modeS.repl_top + txt_off )
   zoneherd.prompt:set(1, 2, modeS.l_margin - 1, 2)
   zoneherd.results:set( modeS.l_margin,
                         modeS.repl_top + txt_off + 1,
                         right_col,
                         modeS.max_row )
   zoneherd.stat_col:set( right_col + 1,
                          1,
                          modeS.max_col,
                          1 )
   zoneherd.suggest:set( right_col + 1,
                         3,
                         modeS.max_col,
                         modeS.max_row )
   for _,z in ipairs(zoneherd) do
      z.touched = true
   end
   return zoneherd
end











local a = require "anterm"

local _hard_nl = a.col(1) .. a.jump.down()

local function _paintGutter(zoneherd)
   local write = zoneherd.write
   local lines = zoneherd.command.contents
                 and #zoneherd.command.contents.lines - 1 or 0
   write(a.erase._box(1, 3, zoneherd.results.tc - 1, zoneherd.results.br))
   write(a.colrow(1,3))
   while lines > 0 do
      write "..."
      write(_hard_nl)
      lines = lines - 1
   end
end

function Zoneherd.paint(zoneherd, modeS, all)
   local write = zoneherd.write
   write(a.cursor.hide())
   write(a.clear())
   if all then
      write(a.erase.all())
   end
   for i, zone in ipairs(zoneherd) do
      if zone.touched or all then
         -- erase
         write(a.erase._box(    zone.tc,
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
         elseif zone == zoneherd.results then
            _writeResults(write, zone)
         end
         zone.touched = false
      end
   end
   zoneherd.write(a.cursor.show())
   _paintGutter(zoneherd)
   modeS:placeCursor()
   return zoneherd
end








local function newZone(tc, tr, bc, br, z, debug_mark)
   assert(tc <= bc, "tc: " .. tc .. ", bc: " .. bc)
   assert(tr <= br, "tr: " .. tr .. ", br: " .. br)
   local zone = meta(Zone)
   zone:set(tc, tr, bc, br)
   zone.debug_mark = debug_mark
   zone.z = z
   zone.touched = false
   -- zone.contents, aspirationally a rainbuf, is provided later
   return zone
end













local function new(modeS, writer)
   local zoneherd = meta(Zoneherd)
   local right_col = modeS.max_col - _zoneOffset(modeS)
   zoneherd.write = writer
   -- make Zones
   -- correct values are provided by reflow
   zoneherd.status  = newZone(-1, -1, -1, -1, 1, ".")
   zoneherd[1] = zoneherd.status
   zoneherd.command = newZone(-1, -1, -1, -1, 1, "|")
   zoneherd[3] = zoneherd.command
   zoneherd.prompt  = newZone(-1, -1, -1, -1, 1, ">")
   zoneherd[2] = zoneherd.prompt
   zoneherd.results = newZone(-1, -1, -1, -1, 1, "~")
   zoneherd[4] = zoneherd.results
   zoneherd.stat_col = newZone(-1, -1, -1, -1, 1, "!")
   zoneherd[5] = zoneherd.stat_col
   zoneherd.suggest = newZone(-1, -1, -1, -1, 1, "%")
   zoneherd[6] = zoneherd.suggest
   zoneherd:reflow(modeS)

   return zoneherd
end



return new
