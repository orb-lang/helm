















local a = require "singletons/anterm"

local core = require "singletons/core"

local C = require "singletons/color"







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
         local key = pre ..
            (type(k) == "string" and k or "<" .. type(k) .. ">")
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

local yield, wrap = assert(coro.yield), assert(coro.wrap)

local concat, insert, remove = assert(table.concat),
                               assert(table.insert),
                               assert(table.remove)

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


















local hasfield = assert(core.hasfield)
local lines = assert(string.lines)

local function _yieldReprs(tab, phrase)
   local isYes, _repr = hasfield.__repr(tab)
   assert(c, "must have a value for c")
   local repr = _repr(tab, phrase, c)
   local yielder
   if type(repr) == "string" then
      yielder = lines(repr)
   else
      yielder = repr
   end
   while true and type(yielder) == 'function' do
      local line, len = yielder()
      if line ~= nil then
         len = len or #line
         yield(line, len, "repr_line")
      else
         break
      end
   end
end











local O_BRACE = function() return c.base "{ " end
local C_BRACE = function() return c.base " }" end
local COMMA, COM_LEN = function() return c.base ", " end, 2

local isarray, table_keys, sort = assert(table.isarray), assert(table.keys), assert(table.sort)

local function _tabulate(tab, depth, cycle, phrase)
   cycle = cycle or {}
   depth = depth or 0
   if type(tab) ~= "table" then
      ts_coro(tab, nil, phrase)
      return nil
   end
   if depth > C.depth or cycle[tab] then
      ts_coro(tab, "tab_name", phrase)
      return nil
   end
   cycle[tab] = true
   -- __repr gets special treatment
   if hasfield.__repr(tab) then
      _yieldReprs(tab, phrase)
      return nil
   end

   -- if we have a metatable, get it first
   local _M = getmetatable(tab)
   if _M then
      ts_coro(tab, "mt", phrase)
      yield(c.base(" = "), 3)
      _tabulate(_M, depth + 1, cycle, phrase)
   end

   -- Okay, we're repring the body of a table of some kind
   -- Check to see if this is an array
   local is_array = isarray(tab)
   -- And print an open brace
   yield(O_BRACE(), 2, (is_array and "array" or "map"))

   if is_array then
      for i, val in ipairs(tab) do
         if i ~= 1 then
            yield(COMMA(), COM_LEN)
         end
         _tabulate(val, depth + 1, cycle, phrase)
      end
   else
      local keys = table_keys(tab)
      if #keys <= SORT_LIMIT then
         sort(keys, _keysort)
      end
      for i, key in ipairs(keys) do
         if i ~= 1 then
            yield(COMMA(), COM_LEN)
         end
         local val = tab[key]
         if type(key) == "string" and key:find("^[%a_][%a%d_]*$") then
            -- legal identifier, display it as a bareword
            ts_coro(key, nil, phrase)
         else
            -- arbitrary string or other type, wrap with braces and repr it
            yield(c.base("["), 1)
            -- we want names or hashes for any lvalue table,
            -- 100 triggers this
            _tabulate(key, 100, cycle, phrase)
            yield(c.base("]"), 1)
         end
         yield(c.base(" = "), 3)
         _tabulate(val, depth + 1, cycle, phrase)
      end
   end
   yield(C_BRACE(), 2, "end")
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
   local new_level = phrase.level
   if #phrase == 0 then
      phrase.yielding = true
      return false
   end
   while true do
      local frag, disp = remove(phrase, 1), remove(phrase.disp, 1)
      insert(line, frag)
      insert(disps, disp)
      -- adjust stack for next round
      if frag == O_BRACE() then
         new_level = new_level + 1
      elseif frag == C_BRACE() then
         new_level = new_level - 1
      end
      if (frag == COMMA() and long)
         or (#phrase == 0 and not phrase.more) then
         local indent = ("  "):rep(phrase.level)
         phrase.level = new_level
         return indent .. concat(line)
      elseif #phrase == 0 and phrase.more then
         -- spill our fragments back
         return _spill(phrase, line, disps)
      end
   end
end









local readOnly = assert(core.readOnly)

local function _remains(phrase)
   return phrase.width - _disp(phrase)
end

local function lineGen(tab, depth, cycle, disp_width)
   assert(disp_width, "lineGen must have a disp_width")
   local phrase = {}
   phrase.disp = {}
   local iter = wrap(_tabulate)
   local stage = {}              -- stage stack
   phrase.remains = _remains
   phrase.width = disp_width
   phrase.stage = stage
   phrase.level = 0              -- how many levels of recursion are we on
   phrase.more = true            -- are their more frags to come
   phrase.yielding = true
   local long = false            -- long or short printing

   -- make a read-only phrase table for fetching values
   local phrase_ro = readOnly(phrase)
   -- return an iterator function which yields one line at a time.
   return function()
      ::start::
      while phrase.yielding do
         local line, len, event = iter(tab, depth, cycle, phrase_ro)
         if line == nil then
            phrase.yielding = false
            phrase.more = false
            break
         end
         phrase[#phrase + 1] = line
         phrase.disp[#phrase.disp + 1] = len
         if event then
            if event == "repr_line" then
               -- remove from the phrase and send directly
               phrase[#phrase] = nil
               phrase.disp[#phrase.disp] = nil
               return line
            end
            if event == "array" or event == "map" then
               insert(stage, event)
            elseif event == "end" then
               remove(stage)
            end
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
   disp_width = disp_width or 80
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









local find, sub, gsub, byte = assert(string.find), assert(string.sub),
                              assert(string.gsub), assert(string.byte)

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













local function c_data(value, str, phrase)
   --local meta = reflect.getmetatable(value)
   yield(str, #str)
   --[[
   if meta then
      yield(c.base " = ", 3)
      ts_coro(meta, nil, phrase)
   end
   --]]
end








ts_coro = function (value, hint, phrase)
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
      _tabulate(value, nil, nil, phrase)
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

function repr.ts_token(tab, hint)
   return wrap(ts_coro)(tab, hint)
end

repr.ts = tabulate





function repr.ts_bw(value)
   c = C.no_color
   local to_string = tabulate(value)
   c = C.color
   return to_string
end



return repr
