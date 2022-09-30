# SelectionList

A list with a concept of an item being "selected"\. Currently used by and
specialized for search results, from either an actual search or `suggest`\.


#### imports

```lua
local core = require "qor:core"
local math = core.math
```


## Interface

### Instance Fields


-  <numbers>:        The items available to select

-  selected\_index:   Index of the currently selected item

-  show\_shortcuts:   Whether to show M\-n shortcut indicators

Search\-specific fields:


-  frag:       The search string that produced the list, to be highlighted
    in the output

-  lit\_frag:   The original search string, unmodified by any fuzzy matching

-  best:       Whether a match was found without employing any fuzzy matching

```lua
local SelectionList = core.cluster.meta {}
local new
```


### SelectionList:selectFirst\(\), :selectNext\(\), :selectPrevious\(\)

Moves the highlight to the first, next or previous item in the list\.
Answers whether the highlight was able to be moved \(false if we're
already at the end/beginning of the list\)

```lua
local clamp = assert(math.clamp)
function SelectionList.selectIndex(list, index)
   -- Handle empty-list case separately as `clamp`
   -- does not tolerate upper < lower
   index = #list == 0 and 0 or clamp(index, 1, #list)
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
```


### SelectionList:selectNextWrap\(\), :selectPreviousWrap\(\)

As :selectNext\(\) and :selectPrevious\(\), but wraps around instead of failing
if we are at the end/beginning of the list\. Answers whether the highlight was
able to be moved\-\-false only if the list has 0 or 1 items\.

```lua
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
```


### SelectionList:selectNone\(\)

De\-selects any selected item\. We use the convention of `selected_index == 0`
to mean no selection\.

```lua
function SelectionList.selectNone(list)
   list.selected_index = 0
end
```


### SelectionList:selectedItem\(\)

Answers the actual selected item from the list \(as opposed to its index\)\.

```lua
function SelectionList.selectedItem(list)
   return list[list.selected_index]
end
```


### \_\_repr

Displays the list, highlighting the currently selected item\.
Optionally provides indicators for Alt\-number \(M\-n\) shortcuts for the
first 10 items of the list\. Also highlights the characters of `frag`
where they appear\.

```lua

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

```


### new\(frag, cfg\)

Creates a new, empty SelectionList\. If `frag` is provided it is used as the search term\. Additional options may be supplied in `cfg`\.

```lua
new = function(frag, cfg)
   local list = setmetatable({}, SelectionList)
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
```

```lua
SelectionList.idEst = new
return new
```
