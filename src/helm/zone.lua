




































































local Txtbuf = require "helm/txtbuf"
local Rainbuf = require "helm/rainbuf"
local a = require "anterm:anterm"

local instanceof = import("core/meta", "instanceof")



local Zone = meta {}
local Zoneherd = meta {}








function Zone.height(zone)
   return zone.br - zone.tr + 1
end

function Zone.width(zone)
   return zone.bc - zone.tc + 1
end









function Zone.overlaps(zone, other_zone)
   -- The other zone may be uninitialized--treat this as nonoverlapping
   if not (other_zone.tc and other_zone.tr and
           other_zone.bc and other_zone.br) then
      return false
   end
   return zone.tc <= other_zone.bc and
          zone.bc >= other_zone.tc and
          zone.tr <= other_zone.br and
          zone.br >= other_zone.tr
end







function Zone.replace(zone, contents)
   zone.contents = contents or ""
   zone:beTouched()
   return zone
end










function Zone.scrollUp(zone)
   if instanceof(zone.contents, Rainbuf)
      and zone.contents:scrollUp() then
      zone:beTouched()
      return true
   else
      return false
   end
end

function Zone.scrollDown(zone)
   if instanceof(zone.contents, Rainbuf)
      and zone.contents:scrollDown() then
      zone:beTouched()
      return true
   else
      return false
   end
end







function Zone.setBounds(zone, tc, tr, bc, br)
   assert(tc <= bc, "tc: " .. tc .. ", bc: " .. bc)
   assert(tr <= br, "tr: " .. tr .. ", br: " .. br)
   if not(zone.tr == tr and
          zone.tc == tc and
          zone.br == br and
          zone.bc == bc) then
      -- If zone width is changing, clear caches of the contained Rainbuf
      -- Note that :setBounds() is called to set zone.(tc,bc,tr,br) for the first time,
      -- so we only check for a change if there are previous values
      if zone.bc and zone.tc
         and (bc - tc) ~= (zone.bc - zone.tc)
         and instanceof(zone.contents, Rainbuf) then
         zone.contents:clearCaches()
      end
      zone.tr = tr
      zone.tc = tc
      zone.br = br
      zone.bc = bc
      -- #todo technically this is incomplete as we need to care about
      -- cells we may previously have owned and no longer do, and what zones
      -- *are* now responsible for them. Doing that properly requires a real
      -- two-step layout process, though (figure out where everything is going
      -- to be, *then* put it there and mark things touched), so we'll
      -- hold off for now
      zone:beTouched()
   end
   return zone
end





function Zone.setVisibility(zone, new_visibility)
   if new_visibility ~= zone.visible then
      zone.visible = new_visibility
      zone:beTouched()
   end
   return zone
end

function Zone.show(zone)
   return zone:setVisibility(true)
end
function Zone.hide(zone)
   return zone:setVisibility(false)
end












function Zone.beTouched(zone)
   if zone.touched then return end
   zone.touched = true
   for _, other_zone in ipairs(zone.zoneherd) do
      if zone.z ~= other_zone.z and
         zone.visible == (other_zone.z > zone.z) and
         zone:overlaps(other_zone) then
         other_zone.touched = true
      end
   end
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





local concat = assert(table.concat)
local c = import("singletons/color", "color")
local Token = require "helm/repr/token"

local function _renderTxtbuf(modeS, zone, write)
   local tokens = modeS.lex(zone.contents)
   for i, tok in ipairs(tokens) do
      -- If suggestions are active and one is highlighted,
      -- display it in grey instead of what the user has typed so far
      -- Note this only applies once Tab has been pressed, as until then
      -- :selectedItem() will be nil
      if tok.cursor_offset and modeS.suggest.active_suggestions
         and modeS.suggest.active_suggestions[1]:selectedItem() then
         tok = Token(modeS.suggest.active_suggestions[1]:selectedItem(), c.base)
      end
      tokens[i] = tok:toString(c)
   end
   _writeLines(write, zone, concat(tokens))
end











local insert = assert(table.insert)

function Zoneherd.addZone(zoneherd, zone)
   zoneherd[zone.name] = zone
   zone.zoneherd = zoneherd
   local insert_index
   for i, existing in ipairs(zoneherd) do
      if existing.z > zone.z then
         insert_index = i
         break
      end
   end
   if insert_index then
      insert(zoneherd, insert_index, zone)
   else
      insert(zoneherd, zone)
   end
   return zoneherd
end









local function newZone(name, z, debug_mark)
   local zone = meta(Zone)
   zone.name = name
   zone.debug_mark = debug_mark
   zone.z = z
   zone.visible = true
   zone.touched = false
   -- zone.contents, aspirationally a rainbuf, is provided later
   return zone
end

function Zoneherd.newZone(zoneherd, name, z, debug_mark)
   return zoneherd:addZone(newZone(name, z, debug_mark))
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





local ceil, floor = assert(math.ceil), assert(math.floor)

function Zoneherd.reflow(zoneherd, modeS)
   local right_col = modeS.max_col - _zoneOffset(modeS)
   local txt_off = modeS:continuationLines()
   zoneherd.status:setBounds(  1, 1, right_col, 1)
   zoneherd.stat_col:setBounds(right_col + 1, 1,
                               modeS.max_col, 1 )
   zoneherd.prompt:setBounds(  1,
                               modeS.repl_top,
                               modeS.l_margin - 1,
                               modeS.repl_top + txt_off )
   zoneherd.command:setBounds( modeS.l_margin,
                               modeS.repl_top,
                               right_col,
                               modeS.repl_top + txt_off )
   zoneherd.results:setBounds( 1,
                               modeS.repl_top + txt_off + 1,
                               right_col,
                               modeS.max_row )
   zoneherd.suggest:setBounds( right_col + 1,
                               modeS.repl_top + 1,
                               modeS.max_col,
                               modeS.max_row )
   -- Popup is centered and 2/3 of max width, i.e. from 1/6 to 5/6
   zoneherd.popup:setBounds(   floor(modeS.max_col / 6),
                               modeS.repl_top + txt_off + 1,
                               ceil(modeS.max_col * 5 / 6),
                               modeS.max_row)
   return zoneherd
end










function Zoneherd.paint(zoneherd, modeS)
   local write = zoneherd.write
   write(a.cursor.hide(), a.clear())
   for i, zone in ipairs(zoneherd) do
      if zone.visible and zone.touched then
         -- erase
         write(a.erase.box( zone.tc,
                            zone.tr,
                            zone.bc,
                            zone.br ),
               a.colrow(zone.tc, zone.tr))
         -- actually render ze contents
         if type(zone.contents) == "string" then
            _writeLines(write, zone, zone.contents)
         elseif instanceof(zone.contents, Txtbuf) then
            _renderTxtbuf(modeS, zone, write)
         else
            _renderRainbuf(write, zone)
         end
      end
      zone.touched = false
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
   zoneherd:newZone("status", 1, ".")
   zoneherd:newZone("stat_col", 1, "!")
   zoneherd:newZone("prompt", 1, ">")
   zoneherd:newZone("command", 1, "$")
   zoneherd:newZone("results", 1, "~")
   zoneherd:newZone("suggest", 1, "%")
   zoneherd:newZone("popup", 2, "^")
   zoneherd.popup.visible = false
   zoneherd:reflow(modeS)

   return zoneherd
end



return new
