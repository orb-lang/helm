




































































local ts = import("helm/repr", "ts")
local concat = assert(table.concat)

local Txtbuf = require "helm/txtbuf"
local Rainbuf = require "helm/rainbuf"
local a = require "anterm:anterm"

local Zone = meta {}
local Zoneherd = meta {}








function Zone.height(zone)
   return zone.br - zone.tr + 1
end

function Zone.width(zone)
   return zone.bc - zone.tc + 1
end








function Zone.replace(zone, contents)
   zone.contents = contents or ""
   zone.touched = true

   return zone
end







function Zone.set(zone, tc, tr, bc, br)
   assert(tc <= bc, "tc: " .. tc .. ", bc: " .. bc)
   assert(tr <= br, "tr: " .. tr .. ", br: " .. br)
   if not(zone.tr == tr and
          zone.tc == tc and
          zone.br == br and
          zone.bc == bc) then
      zone.tr = tr
      zone.tc = tc
      zone.br = br
      zone.bc = bc
      zone.touched = true
   end
   return zone
end






local lines = import("core/string", "lines")

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








local instanceof = import("core/meta", "instanceof")

local function _renderRainbuf(write, zone)
   if not zone.contents then
      return nil
   end
   assert(instanceof(zone.contents, Rainbuf))
   local nl = a.col(zone.tc) .. a.jump.down(1)
   for line in zone.contents:lineGen(zone:height(), zone:width()) do
      write(line)
      write(nl)
   end
end





local c = import("singletons/color", "color")

local function _renderTxtbuf(modeS, zone, write)
   local tokens = modeS.lex(zone.contents)
   for i, tok in ipairs(tokens) do
      tokens[i] = tok:toString(c)
   end
   _writeLines(write, zone, concat(tokens))
end











local function newZone(name, tc, tr, bc, br, z, debug_mark)
   local zone = meta(Zone)
   zone.name = name
   zone.debug_mark = debug_mark
   zone.z = z
   zone:set(tc, tr, bc, br)
   zone.touched = false
   -- zone.contents, aspirationally a rainbuf, is provided later
   return zone
end

function Zoneherd.newZone(zoneherd, name, tc, tr, bc, br, z, debug_mark)
   zoneherd[name] = newZone(name, tc, tr, bc, br, z, debug_mark)
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





function Zoneherd.reflow(zoneherd, modeS)
   local right_col = modeS.max_col - _zoneOffset(modeS)
   local txt_off = modeS:continuationLines()
   zoneherd.status:set(1, 1, right_col, 1)
   zoneherd.prompt:set(  1,
                         modeS.repl_top,
                         modeS.l_margin - 1,
                         modeS.repl_top + txt_off)
   zoneherd.command:set( modeS.l_margin,
                         modeS.repl_top,
                         right_col,
                         modeS.repl_top + txt_off )
   zoneherd.results:set( 1,
                         modeS.repl_top + txt_off + 1,
                         right_col,
                         modeS.max_row )
   zoneherd.stat_col:set( right_col + 1,
                          1,
                          modeS.max_col,
                          1 )
   zoneherd.suggest:set( right_col + 1,
                         modeS.repl_top + 1,
                         modeS.max_col,
                         modeS.max_row )
   return zoneherd
end










function Zoneherd.paint(zoneherd, modeS)
   local write = zoneherd.write
   write(a.cursor.hide(), a.clear())
   for i, zone in ipairs(zoneherd) do
      if zone.touched then
         -- erase
         write(a.erase.box( zone.tc,
                            zone.tr,
                            zone.bc,
                            zone.br ),
               a.colrow(zone.tc, zone.tr))
         -- actually render ze contents
         if type(zone.contents) == "string" then
            _writeLines(write, zone, zone.contents)
         elseif type(zone.contents) == "table"
            and zone.contents.idEst == Txtbuf then
            _renderTxtbuf(modeS, zone, write)
         else
            _renderRainbuf(write, zone)
         end
         zone.touched = false
      end
   end
   modeS:placeCursor()
   write(a.cursor.show())
   return zoneherd
end












local function new(modeS, writer)
   local zoneherd = meta(Zoneherd)
   zoneherd.write = writer
   -- make Zones
   -- correct values are provided by reflow
   zoneherd:newZone("status", -1, -1, -1, -1, 1, ".")
   zoneherd:newZone("stat_col", -1, -1, -1, -1, 1, "!")
   zoneherd:newZone("prompt", -1, -1, -1, -1, 1, ">")
   zoneherd:newZone("command", -1, -1, -1, -1, 1, "$")
   zoneherd:newZone("gutter", -1, -1, -1, -1, 1, "_")
   zoneherd:newZone("results", -1, -1, -1, -1, 1, "~")
   zoneherd:newZone("suggest", -1, -1, -1, -1, 1, "%")
   zoneherd:reflow(modeS)

   return zoneherd
end



return new
