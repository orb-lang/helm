



























































local lineGen = import("repr:repr", "lineGen")






local Rainbuf = meta {}












local clear = assert(table.clear)
function Rainbuf.clearCaches(rainbuf)
   clear(rainbuf.lines)
end








local lines = import("core/string", "lines")
function Rainbuf.initComposition(rainbuf, cols)
   cols = cols or 80
   if rainbuf.scrollable then
      cols = cols - 3
   end
   -- If width is changing, we need a re-render
   -- "live" means re-render every time
   if cols ~= rainbuf.cols or rainbuf.live then
      rainbuf:clearCaches()
   end
   rainbuf.cols = cols
   rainbuf.more = true
end











local insert = assert(table.insert)
function Rainbuf.composeOneLine(rainbuf)
   local line = rainbuf:_composeOneLine()
   if line then
      insert(rainbuf.lines, line)
      return true
   else
      rainbuf.more = false
      return false
   end
end
















function Rainbuf.composeUpTo(rainbuf, line_number)
   while rainbuf.more and #rainbuf.lines <= line_number do
      rainbuf:composeOneLine()
   end
   return rainbuf
end








function Rainbuf.composeAll(rainbuf)
   while rainbuf.more do
      rainbuf:composeOneLine()
   end
   return rainbuf
end












function Rainbuf.lineGen(rainbuf, rows, cols)
   rainbuf:initComposition(cols)
   -- state for iterator
   local cursor = rainbuf.offset
   local max_row = rainbuf.offset + rows
   local function _nextLine()
      -- Off the end
      if cursor >= max_row then
         return nil
      end
      cursor = cursor + 1
      rainbuf:composeUpTo(cursor)
      local prefix = ""
      if rainbuf.scrollable then
         -- If this is the last line requested, but more are available,
         -- prepend a continuation marker, otherwise left padding
         prefix = "   "
         if cursor == max_row and rainbuf.more then
            prefix = a.red "..."
         end
      end
      return rainbuf.lines[cursor] and prefix .. rainbuf.lines[cursor]
   end
   return _nextLine
end











function Rainbuf.replace(rainbuf)
   rainbuf:clearCaches()
end









function Rainbuf._init(rainbuf)
   rainbuf.n = 0
   rainbuf.offset = 0
   rainbuf.lines = {}
end






function Rainbuf.__call(buf_class, res, cfg)
   if type(res) == "table" then
      if res.idEst == buf_class then
         return res
      elseif res.is_rainbuf then
         error("Trying to make a Rainbuf from another type of Rainbuf")
      end
   end
   local buf_M = getmetatable(buf_class)
   local rainbuf = setmetatable({}, buf_M)
   rainbuf:_init()
   rainbuf:replace(res)
   if cfg then
      for k, v in pairs(cfg) do
         rainbuf[k] = v
      end
   end
   return rainbuf
end












local sub = assert(string.sub)
function Rainbuf.inherit(buf_class, cfg)
   local parent_M = getmetatable(buf_class)
   local child_M = setmetatable({}, parent_M)
   -- Copy metamethods because mmethod lookup does not respect =__index=es
   for k,v in pairs(parent_M) do
      if sub(k, 1, 2) == "__" then
         child_M[k] = v
      end
   end
   -- But, the new MT should have itself as __index, not the parent
   child_M.__index = child_M
   if cfg then
      -- this can override the above metamethod assignment
      for k,v in pairs(cfg) do
         child_M[k] = v
      end
   end
   return child_M
end








Rainbuf.super = assert(require "core:cluster" . super)









Rainbuf.is_rainbuf = true




local Rainbuf_class = setmetatable({}, Rainbuf)
Rainbuf.idEst = Rainbuf_class

return Rainbuf_class

