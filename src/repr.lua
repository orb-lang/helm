















local a = require "anterm"

local core = require "core"

local reflect = require "reflect"

local C = require "color"







local repr = {}

local hints = C.color.hints

local c = C.color










local anti_G = { _G = "_G" }



















local function tie_break(old, new)
   return #old > #new
end


local function addName(t, aG, pre)
   pre = pre or ""
   aG = aG or anti_G
   if pre ~= "" then
      pre = pre .. "."
   end
   for k, v in pairs(t) do
      local T = type(v)
      if (T == "table") then
         local key = pre .. (type(k) == "string" and k or "<" .. type(k) .. ">")
         if not aG[v] then
            aG[v] = key
            if not (pre == "" and k == "package") then
               addName(v, aG, key)
            end
         else
            local kv = aG[v]
            if tie_break(kv, key) then
               -- quadradic lol
               aG[v] = key
               addName(v, aG, key)
            end
         end
         local _M = getmetatable(v)
         local _M_id = _M and "⟨" .. key.. "⟩" or ""
         if _M then
            if not aG[_M] then
               addName(_M, aG, _M_id)
               aG[_M] = _M_id
            else
               local aG_M_id = aG[_M]
               if tie_break(aG_M_id, _M_id) then
                  addName(_M, aG, _M_id)
                  aG[_M] = _M_id
               end
            end
         end
      elseif T == "function" or
         T == "thread" or
         T == "userdata" then
         aG[v] = pre .. k
      end
   end
   return aG
end









function repr.allNames(tab)
   tab = tab or _G
   return addName(package.loaded, addName(tab))
end

function repr.clearNames()
   anti_G = {_G = "_G"}
   return anti_G
end











local ts, ts_coro

local SORT_LIMIT = 500  -- This won't be necessary #todo remove

local coro = coro or coroutine

local yield, wrap = coro.yield, coro.wrap

local concat, insert, remove = table.concat, table.insert, table.remove

local function _keysort(a, b)
   if (type(a) == "string" and type(b) == "string")
      or (type(a) == "number" and type(b) == "number") then
      return a < b
   elseif type(a) == "number" and type(b) == "string" then
      return true
   elseif type(a) == "string" and type(b) == "number" then
      return false
   else
      return false
   end
end


















local function _yieldReprs(tab, disp)
   local _repr = getmetatable(tab).__repr
   local repr = _repr(tab, disp)
   local yielder
   if type(repr) == "string" then
      yielder = string.lines(repr)
   else
      yielder = repr
   end
   while true do
      local line, len = yielder()
      if line ~= nil then
         len = len or #line
         yield(line, len, "repr_line")
      else
         break
      end
   end
end













local O_BRACE = function() return c.base "{" end
local C_BRACE = function() return c.base "}" end
local COMMA, COM_LEN = function() return c.base ", " end, 2

local function _tabulate(tab, depth, cycle)
   cycle = cycle or {}
   depth = depth or 0
   if type(tab) ~= "table" then
      ts_coro(tab)
      return nil
   end
   if depth > C.depth or cycle[tab] then
      ts_coro(tab, "tab_name")
      return nil
   end
   cycle[tab] = true
   -- if we have a metatable, get it first
   local _M = getmetatable(tab)
   if _M then
      ---[[special case tables with __repr
      if _M.__repr then
         _yieldReprs(tab)
         return nil
      end
      --]]
      --otherwise print the metatable normally
      ts_coro(tab, "mt")
      yield(c.base(" = "), 3)
      _tabulate(_M, depth + 1, cycle)
   end
   -- Check to see if this is an array
   local is_array = true
   local i = 1
   for k,_ in pairs(tab) do
      is_array = is_array and (k == i)
      i = i + 1
   end

   local keys
   if not is_array then
      keys = table.keys(tab)
      if #keys <= SORT_LIMIT then
         table.sort(keys, _keysort)
      end
   else
      keys = tab
   end
   yield(O_BRACE(), 1, (is_array and "array" or "map"))
   for j, key in ipairs(keys) do
      if is_array then
         _tabulate(key, depth + 1, cycle)
      else
         val = tab[key]
         if type(key) == "string" and key:find("^[%a_][%a%d_]*$") then
            ts_coro(key)
            yield(c.base(" = "), 3)
         else
            yield(c.base("["), 1)
               -- we want names or hashes for any lvalue table,
               -- 100 triggers this
            _tabulate(key, 100, cycle)
            yield(c.base("] = "), 4)
         end
         _tabulate(val, depth + 1, cycle)
      end
   end
   yield(C_BRACE(), 1, "end")
   return nil
end


































local function _disp(phrase)
   local displacement = 0
   for i = 1, #phrase.disp do
      displacement = displacement + phrase.disp[i]
   end
   return displacement
end

local function _spill(phrase, line, disps)
   assert(#line == #disps, "#line must == #disps")
   for i = 0, #line do
      phrase[i] = line[i]
      phrase.disp[i] = disps[i]
   end
   phrase.yielding = true
   return false
end

local function oneLine(phrase, long)
   local line = {}
   local disps = {}
   if #phrase == 0 then
      phrase.yielding = true
      return false
   end
   while true do
      local frag, disp = remove(phrase, 1), remove(phrase.disp, 1)
      -- remove commas before closing braces
      if frag == COMMA() then
         if phrase[1] == C_BRACE() then
            frag = ""
            disp = 0
         elseif #phrase == 0 then
            insert(line, frag)
            insert(disps, disp)
            return _spill(phrase, line, disps)
         end
      end
      -- and after opening braces
      if frag == O_BRACE() and phrase[1] == COMMA() then
         remove(phrase, 1)
         remove(phrase.disp, 1)
      end
      -- pad with a space inside the braces
      if frag == C_BRACE() then
         insert(line, " ")
         insert(disps, 1)
      end
      insert(line, frag)
      insert(disps, disp)
      if frag == O_BRACE() then
         insert(line, " ")
         insert(disps, 1)
      end
      -- adjust stack for next round
      if frag == O_BRACE() then
         phrase.level = phrase.level + 1
      elseif frag == C_BRACE() then
         phrase.level = phrase.level - 1
      end
      if (frag == COMMA() and long)
         or (#phrase == 0 and not phrase.more) then
         local indent = phrase.dent == 0 and "" or ("  "):rep(phrase.dent)
         phrase.dent = phrase.level
         return indent.. concat(line)
      elseif #phrase == 0 and phrase.more then
         -- spill our fragments back
         return _spill(phrase, line, disps)
      end
   end
end








local function lineGen(tab, depth, cycle, disp_width)
   local phrase = {}
   phrase.disp = {}
   local iter = wrap(_tabulate)
   local stage = {}              -- stage stack
   phrase.stage = stage
   phrase.level = 0              -- how many levels of recursion are we on
   phrase.dent = 0               -- indent level (lags by one line)
   phrase.more = true            -- are their more frags to come
   local map_counter = 0         -- counts where commas go
   phrase.yielding = true
   local long = false            -- long or short printing
                                 -- todo maybe attach to phrase?
   -- return an iterator function which yields one line at a time.
   return function()
      ::start::
      while phrase.yielding do
         local line, len, event = iter(tab, depth, cycle)
         if line == nil then
            phrase.yielding = false
            phrase.more = false
            break
         end
         phrase[#phrase + 1] = line
         phrase.disp[#phrase.disp + 1] = len
         if event then
            if event == "repr_line" then
               phrase[#phrase] = nil
               return line
            end
            if event == "map" then
               map_counter = 0
            end
            if event == "array" or event == "map" then
               insert(stage, event)
            elseif event == "end" then
               remove(stage)
               if stage[#stage] == "map" then
                  map_counter = 3
               end
            elseif event == "mt_name" then
               -- gotta drop that comma
               map_counter = 1
            end
         end
         -- special-case for non-string values, which
         -- yield an extra piece
         if line == c.base("] = ") then
            map_counter = map_counter - 1
         end
         -- insert commas
         if stage[#stage] =="map"  then
            if map_counter == 3 then
               phrase[#phrase + 1] = COMMA()
               phrase.disp[#phrase.disp + 1] = COM_LEN
               map_counter = 1
            else
               map_counter = map_counter + 1
            end
         elseif stage[#stage] == "array"then
            phrase[#phrase + 1] = COMMA()
            phrase.disp[#phrase.disp + 1] = COM_LEN
            map_counter = map_counter + 1
         end
         if _disp(phrase) >= disp_width then
            long = true
            phrase.yielding = false
            break
         else
            long = false
         end
      end
      if #phrase > 0 then
         local ln = oneLine(phrase, long)
         if ln then
            return ln
         else
            goto start
         end
      elseif phrase.more == false then
         return nil
      else
         phrase.yielding = true
         goto start
      end
   end
end

function repr.lineGen(tab, disp)
   disp = disp or 80
   return lineGen(tab, nil, nil, disp)
end













function repr.lineGenBW(tab, disp_width)
   local lg = lineGen(tab, nil, nil, disp_width)
   return function()
      c = C.no_color
      local line = lg()
      if line ~= nil then
         c = C.color
         return line
      end
      c = C.color
      return nil
   end
end



local function tabulate(tab, depth, cycle, disp_width)
   disp_width = disp_width or 80
   local phrase = {}
   for line in lineGen(tab, depth, cycle, disp_width) do
      phrase[#phrase + 1] = line
   end
   return concat(phrase, "\n")
end









local find, sub, gsub, byte = string.find, string.sub,
                              string.gsub, string.byte

local e = function(str)
   return c.stresc .. str .. c.string
end

-- Turn control characters into their byte rep,
-- preserving escapes
local function ctrl_pr(str)
   if byte(str) ~= 27 then
      return e("\\" .. byte(str))
   else
      return str
   end
end

local function scrub (str)
   return str:gsub("\27", e "\\x1b")
             :gsub('"',  e '\\"')
             :gsub("'",  e "\\'")
             :gsub("\a", e "\\a")
             :gsub("\b", e "\\b")
             :gsub("\f", e "\\f")
             :gsub("\n", e "\\n")
             :gsub("\r", e "\\r")
             :gsub("\t", e "\\t")
             :gsub("\v", e "\\v")
             :gsub("%c", ctrl_pr)
end



local function c_data(value, str)
   local meta = reflect.getmetatable(value)
   if meta then
      local mt_str, meta_len = ts(meta)
      meta_len = meta_len or #mt_str
      return str .. " = " .. mt_str, meta_len
   else
      return str, #str
   end
end







ts_coro = function (value, hint)
   local strval = tostring(value) or ""
   local len = #strval
   local str = scrub(strval)

   -- For cases more specific than mere type,
   -- we have hints:
   if hint then
      if hint == "tab_name" then
         local tab_name = anti_G[value] or "t:" .. sub(str, -6)
         len = #tab_name
         yield(c.table(tab_name), len)
         return nil
      elseif hint == "mt" then
         local mt_name = anti_G[value] or "mt:" .. sub(str, -6)
         len = #mt_name + 2
         yield(c.metatable("⟨" .. mt_name .. "⟩"), len, "mt_name")
         return nil
      elseif hints[hint] then
         yield(hints[hint](str), len)
         return nil
      elseif c[hint] then
         yield(c[hint](str), len)
         return nil
      end
   end

   local typica = type(value)

   if typica == "table" then
      _tabulate(value)
      return nil
   elseif typica == "function" then
      local f_label = sub(str,11)
      f_label = sub(f_label,1,5) == "built"
                and f_label
                or "f:" .. sub(str, -6)
      local func_name = anti_G[value] or f_label
      len = #func_name
      str = c.func(func_name)
   elseif typica == "boolean" then
      str = value and c.truth(str) or c.falsehood(str)
   elseif typica == "string" then
      if value == "" then
         str = c.string('""')
         len = 2
      else
         str = c.string(str)
      end
   elseif typica == "number" then
      str = c.number(str)
   elseif typica == "nil" then
      str = c.nilness(str)
   elseif typica == "thread" then
      local coro_name = anti_G[value] and "coro:" .. anti_G[value]
                                      or  "coro:" .. sub(str, -6)
      len = #coro_name
      str = c.thread(coro_name)
   elseif typica == "userdata" then
      if anti_G[value] then
         str = c.userdata(anti_G[value])
         len = #anti_G[value]
      else
         local name = find(str, ":")
         if name then
            name = sub(str, 1, name - 1)
            len = #name
            str = c.userdata(name)
         else
            str = c.userdata(str)
         end
      end
   elseif typica == "cdata" then
      if anti_G[value] then
         str = c.cdata(anti_G[value])
         len = anti_G[value]
      else
         str = c.cdata(str)
      end
      str, len = c_data(value, str)
   end
   yield(str, len)
end

repr.ts = tabulate



function repr.ts_bw(value)
   c = C.no_color
   local to_string = tabulate(value)
   c = C.color
   return to_string
end



return repr
