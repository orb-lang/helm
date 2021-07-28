




















local SelectionList = meta {}
local new










local clamp = assert(require "core:math" . clamp)
function SelectionList.selectIndex(list, index)
   index = clamp(index, 1, #list)
   if index ~= list.selected_index then
      list.selected_index = index
      return true
   else
      return false
   end
end

function SelectionList.selectFirst(list)
   return list:selectIndex(1)
end

function SelectionList.selectNext(list)
   return list:selectIndex(list.selected_index + 1)
end

function SelectionList.selectPrevious(list)
   return list:selectIndex(list.selected_index - 1)
end










function SelectionList.selectNextWrap(list)
   local new_idx = list.selected_index < #list
      and list.selected_index + 1
      or 1
   return list:selectIndex(new_idx)
end

function SelectionList.selectPreviousWrap(list)
   local new_idx = list.selected_index > 1
      and list.selected_index - 1
      or #list
   return list:selectIndex(new_idx)
end









function SelectionList.selectNone(list)
   list.selected_index = 0
end








function SelectionList.selectedItem(list)
   return list[list.selected_index]
end












local Codepoints = require "singletons/codepoints"
local concat = assert(table.concat)

function SelectionList.highlight(list, line, max_disp, c)
   local frag_index = 1
   -- Collapse multiple spaces into one for display
   line = line:gsub(" +"," ")
   local codes = Codepoints(line)
   local disp = 0
   local stop_at
   for i, char in ipairs(codes) do
      local char_disp = 1
      if char == "\n" then
         char = c.stresc .. "\\n" .. c.base
         codes[i] = char
         char_disp =  2
      end
      -- Reserve one space for ellipsis unless this is the
      -- last character on the line
      local reserved_space = i < #codes and 1 or 0
      if disp + char_disp + reserved_space > max_disp then
         char = c.alert("…")
         codes[i] = char
         disp = disp + 1
         stop_at = i
         break
      end
      disp = disp + char_disp
      if frag_index <= #list.frag and char == list.frag:sub(frag_index, frag_index) then
         local char_color
         -- highlight the last two differently if this is a
         -- 'second best' search
         if not list.best and #list.frag - frag_index < 2 then
            char_color = c.alert
         else
            char_color = c.search_hl
         end
         char = char_color .. char .. c.base
         codes[i] = char
         frag_index = frag_index + 1
      end
   end
   return c.base(concat(codes, "", 1, stop_at)), disp
end

function SelectionList.__repr(list, window, c)
   assert(c, "must provide a color table")
   if #list == 0 then
      return c.alert "No results found"
   end
   local i = 1
   return function()
      local line = list[i]
      local len
      if line == nil then return nil end
      line, len = list:highlight(line, window.remains - 4, c)
      if list.show_shortcuts then
         local alt_seq = "    "
         if i < 10 then
            alt_seq = c.bold("M-" .. tostring(i) .. " ")
         end
         line = alt_seq .. line
         len = len + 4
      end
      if i == list.selected_index then
         line = c.highlight(line)
      end
      i = i + 1
      return line, len
   end
end









new = function(frag, cfg)
   local list = meta(SelectionList)
   if frag then
      list.frag = frag
      list.lit_frag = frag
      list.best = true
   end
   list.selected_index = 0
   -- list.n = 0
   if cfg then
      for k, v in pairs(cfg) do
         list[k] = v
      end
   end
   return list
end



SelectionList.idEst = new
return new

