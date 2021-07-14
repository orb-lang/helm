




































































local Txtbuf = require "helm:buf/txtbuf"
local Rainbuf = require "helm:buf/rainbuf"
local a = require "anterm:anterm"

local instanceof = import("core/meta", "instanceof")



local Zone = meta {}
local Zoneherd = meta {}









function Zone.height(zone)
   return zone.bounds:height()
end
function Zone.width(zone)
   return zone.bounds:width()
end











local Point = require "anterm:point"
function Zone.clientBounds(zone)
   if zone.border then
      return zone.bounds:insetBy(Point(1,2))
   else
      return zone.bounds
   end
end










function Zone.overlaps(zone, other_zone)
   -- One or both zones may be uninitialized--treat this as nonoverlapping
   return zone.bounds
      and other_zone.bounds
      and zone.bounds:intersects(other_zone.bounds)
end








local function update_content_extent(zone)
   if zone.bounds and zone.contents.is_rainbuf then
      zone.contents:setExtent(zone:clientBounds():extent():rowcol())
   end
end

function Zone.replace(zone, contents)
   zone.contents = contents or ""
   -- #todo shouldn't have to do this nearly as often--Zone contents will
   -- change much less once Window refactoring is done--though this may still
   -- be the right place to do it
   update_content_extent(zone)
   zone:beTouched()
   return zone
end









local Rectangle  = require "anterm/rectangle"
function Zone.setBounds(zone, rect, ...)
   if not instanceof(rect, Rectangle) then
      rect = Rectangle(rect, ...)
   end
   rect:assertNotEmpty("Zone '" .. zone.name .. "' must have non-zero area")
   if zone.bounds ~= rect then
      zone.bounds = rect
      update_content_extent(zone)
      -- Technically this could be incomplete in the case where we relinquish some cells,
      -- but as long as every cell is covered by at least one Zone by the time layout is
      -- complete, the new owner will figure things out.
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










for _, scroll_fn in ipairs{
   "scrollTo", "scrollBy",
   "scrollUp", "scrollDown",
   "pageUp", "pageDown",
   "halfPageUp", "halfPageDown",
   "scrollToTop", "scrollToBottom",
   "ensureVisible"
} do
   Zone[scroll_fn] = function(zone, ...)
      if zone.contents.is_rainbuf then
         return zone.contents[scroll_fn](zone.contents, ...)
      else
         return false
      end
   end
end









local box = require "anterm/box"
function Zone.paintBorder(zone, write)
   if zone.border then
      write(box[zone.border](zone.bounds))
   end
end






function Zone.erase(zone, write)
   write(a.erase.box(zone.bounds))
end






local function _nl(zone)
   return a.jump.col(zone:clientBounds().left) .. a.jump.down(1)
end

local lines = import("core/string", "lines")

local function _writeLines(write, zone)
   local nl = _nl(zone)
   local pr_row = zone.bounds.top
   for line in lines(zone.contents) do
       write(line, nl)
       pr_row = pr_row + 1
       if pr_row > zone.bounds.bottom then
          break
       end
   end
end

local function _renderRainbuf(write, zone)
   if not zone.contents then
      return nil
   end
   assert(zone.contents.is_rainbuf)
   local nl = _nl(zone)
   for line in zone.contents:lineGen(zone:clientBounds():extent():rowcol()) do
      write(line, nl)
   end
end

function Zone.paint(zone, write)
   if not (zone.visible and zone.touched) then
      return
   end
   zone:erase(write)
   zone:paintBorder(write)
   if zone.contents then
      write(a.jump(zone:clientBounds():origin()))
      -- actually render ze contents
      if type(zone.contents) == "string" then
         _writeLines(write, zone)
      else
         _renderRainbuf(write, zone)
      end
   end
   zone.touched = false
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
   zone.contents = ''
   return zone
end

function Zoneherd.newZone(zoneherd, name, z, debug_mark)
   return zoneherd:addZone(newZone(name, z, debug_mark))
end






local function _zoneOffset(modeS)
   local width = modeS.max_extent.col
   if width <= 80 then
      return 20
   elseif width <= 100 then
      return 30
   elseif width <= 120 then
      return 40
   else
      return 50
   end
end






local ceil, floor = assert(math.ceil), assert(math.floor)

function Zoneherd.reflow(zoneherd, modeS)
   local right_col = modeS.max_extent.col - _zoneOffset(modeS)
   local txt_off = modeS.maestro.agents.edit:continuationLines()
   zoneherd.status:setBounds(  1, 1, 1, right_col)
   zoneherd.stat_col:setBounds(1, right_col + 1,
                               1, modeS.max_extent.col )
   zoneherd.prompt:setBounds(  modeS.repl_top,
                               1,
                               modeS.repl_top + txt_off,
                               modeS.PROMPT_WIDTH )
   zoneherd.command:setBounds( modeS.repl_top,
                               modeS.PROMPT_WIDTH + 1,
                               modeS.repl_top + txt_off,
                               right_col )
   local results_right
   if zoneherd.suggest.visible then
      results_right = right_col
      zoneherd.suggest:setBounds( modeS.repl_top + 1,
                                  right_col + 1,
                                  modeS.max_extent.row,
                                  modeS.max_extent.col )
   else
      results_right = modeS.max_extent.col
   end
   zoneherd.results:setBounds( modeS.repl_top + txt_off + 1,
                               1,
                               modeS.max_extent.row,
                               results_right )
   -- Popup is centered and 2/3 of max width, i.e. from 1/6 to 5/6
   zoneherd.popup:setBounds(   modeS.repl_top + txt_off + 1,
                               floor(modeS.max_extent.col / 6),
                               modeS.max_extent.row,
                               ceil(modeS.max_extent.col * 5 / 6) )
   -- Modal is centered vertically and horizontally, with the extent
   -- determined by the contents. Modal only tells us the client area
   -- required, we must account for the borders--seems like a good
   -- division of responsibility.
   if zoneherd.modal.visible then
      local modal_extent = modeS.maestro.agents.modal.model:requiredExtent() + Point(2, 4)
      local margins = ((modeS.max_extent - modal_extent) / 2):floor()
      zoneherd.modal:setBounds(margins.row, margins.col,
                               (margins + modal_extent - 1):rowcol())
   end
   return zoneherd
end










function Zoneherd.paint(zoneherd, modeS)
   local write = zoneherd.write
   write(a.cursor.hide(), a.clear())
   for i, zone in ipairs(zoneherd) do
      -- Propagate touched-ness so it can also spread "horizontally"
      -- to neighboring Zones
      -- #todo There has *got* to be a better way than this. An events
      -- framework would work, might be other options
      if zone.contents.is_rainbuf and zone.contents:checkTouched() then
         zone:beTouched()
      end
   end
   for i, zone in ipairs(zoneherd) do
      zone:paint(write)
   end
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
   zoneherd.popup.border = "light"
   zoneherd:newZone("modal", 2, "?")
   zoneherd.modal.visible = false
   zoneherd.modal.border = "light"

   return zoneherd
end



return new

