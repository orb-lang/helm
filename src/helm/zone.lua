




































































local Txtbuf = require "helm/txtbuf"
local Rainbuf = require "helm/rainbuf"
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







function Zone.replace(zone, contents)
   zone.contents = contents or ""
   zone:beTouched()
   return zone
end




















local clamp = import("core/math", "clamp")
function Zone.scrollTo(zone, offset, allow_overscroll)
   local buf = zone.contents
   if not buf.is_rainbuf then
      return false
   end
   -- Try to render the content that will be visible after the scroll
   local client_height = zone:clientBounds():height()
   buf:initComposition(zone:clientBounds():width())
   buf:composeUpTo(offset + client_height)
   local required_lines_visible = allow_overscroll and 1 or client_height
   local max_offset = clamp(#buf.lines - required_lines_visible, 0)
   offset = clamp(offset, 0, max_offset)
   if offset ~= buf.offset then
      buf.offset = offset
      zone:beTouched()
      return true
   else
      return false
   end
end








function Zone.scrollBy(zone, delta, allow_overscroll)
   -- Need to check this here even though :scrollTo already does
   -- because we talk to the Rainbuf to figure out the new offset
   if not zone.contents.is_rainbuf then
      return false
   end
   return zone:scrollTo(zone.contents.offset + delta, allow_overscroll)
end








function Zone.scrollUp(zone)
   return zone:scrollBy(-1)
end
function Zone.scrollDown(zone)
   return zone:scrollBy(1)
end

function Zone.pageUp(zone)
   return zone:scrollBy(-zone:height())
end
function Zone.pageDown(zone)
   return zone:scrollBy(zone:height())
end

local floor = assert(math.floor)
function Zone.halfPageUp(zone)
   return zone:scrollBy(-floor(zone:height() / 2))
end
function Zone.halfPageDown(zone)
   return zone:scrollBy(floor(zone:height() / 2))
end











function Zone.scrollToTop(zone)
   return zone:scrollTo(0)
end

function Zone.scrollToBottom(zone, allow_overscroll)
   zone.contents:composeAll()
   -- Choose a definitely out-of-range value,
   -- which scrollTo will clamp appropriately
   return zone:scrollTo(#zone.contents.lines, allow_overscroll)
end











function Zone.ensureVisible(zone, start_index, end_index)
   end_index = end_index or start_index
   local min_offset = clamp(end_index - zone:clientBounds():height(), 0)
   local max_offset = clamp(start_index - 1, 0)
   zone:scrollTo(clamp(zone.contents.offset, min_offset, max_offset))
end









local Rectangle  = require "anterm/rectangle"
function Zone.setBounds(zone, rect, ...)
   if not instanceof(rect, Rectangle) then
      rect = Rectangle(rect, ...)
   end
   rect:assertNotEmpty("Zone must have non-zero area")
   if zone.bounds ~= rect then
      if zone.bounds
         and zone.bounds:width() ~= rect:width()
         and zone.contents
         and zone.contents.is_rainbuf then
         zone.contents:clearCaches()
      end
      zone.bounds = rect
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
   -- zone.contents, aspirationally a rainbuf, is provided later
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
   local txt_off = modeS:continuationLines()
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
      local modal_extent = zoneherd.modal.contents[1]:requiredExtent() + Point(2, 4)
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

