






local Token = require "helm/repr/token"
local import = assert(require "core/module" . import)





local names = {}













local anti_G = setmetatable({ _G = "_G" }, {__mode = "k"})
names.all_symbols = { _G = true }

















local function tie_break(old, new)
   return #old > #new
end

local isidentifier = import("core/string", "isidentifier")

local addName, loadNames

addName = function(value, name, aG)
   local existing = aG[value]
   if not existing or tie_break(existing, name) then
      aG[value] = name
      if type(value) == "table" then
         loadNames(value, name, aG)
      end
   end
end

loadNames = function(tab, prefix, aG)
   if prefix ~= "" then
      prefix = prefix .. "."
   end
   aG = aG or anti_G
   for k, v in pairs(tab) do
      if type(k) == "string" then
         -- Only add legal identifiers to all_symbols, since this is
         -- used for autocomplete
         if isidentifier(k) then
            names.all_symbols[k] = true
         end
      else
         -- #todo should we put <> around non-identifier strings? I guess
         -- it seems fine not to, since this is just for display...
         k = "<" .. tostring(k) .. ">"
      end
      local typica = type(v)
      if typica == "table"
      or typica == "function"
      or typica == "thread"
      or typica == "userdata" then
         addName(v, k, aG)
      end
      local _M = getmetatable(v)
      if typica == "table" and _M then
         local _M_id = "⟨" .. k.. "⟩"
         addName(_M, _M_id, aG)
      end
   end
end

function names.addName(value, name)
   addName(value, name, anti_G)
end

function names.loadNames(tab, prefix)
   tab = tab or _G
   prefix = prefix or ""
   loadNames(tab, prefix, anti_G)
end

function names.clearNames()
   anti_G = {_G = "_G"}
   names.all_symbols = {}
end













local function _rawtostring(val)
   local ts
   if type(val) == "table" then
      -- get metatable and check for __tostring
      local M = getmetatable(val)
      if M and M.__tostring then
         -- cache the tostring method and put it back
         local __tostring = M.__tostring
         M.__tostring = nil
         ts = tostring(val)
         M.__tostring = __tostring
      end
   end
   if not ts then
      ts = tostring(val)
   end
   return ts
end

function names.nameFor(value, c, hint)
   local str
   -- Hint provides a means to override the "type" of the value,
   -- to account for cases more specific than mere type
   local typica = hint or type(value)
   -- Start with the color corresponding to the type--may be overridden below
   local color = c[typica]
   local cfg = {}

   -- Value types are generally represented by their tostring()
   if typica == "string"
      or typica == "number"
      or typica == "boolean"
      or typica == "nil" then
      str = tostring(value)
      if typica == "string" then
         cfg.wrappable = true
      elseif typica == "boolean" then
         color = value and c["true"] or c["false"]
      end
      return Token(str, color, cfg)
   end

   -- For other types, start by looking for a name in anti_G
   if anti_G[value] then
      str = anti_G[value]
      if typica == "thread" then
         -- Prepend coro: even to names from anti_G to more clearly
         -- distinguish from functions
         str = "coro:" .. str
      end
      return Token(str, color, cfg)
   end

   -- If not found, construct one starting with the tostring()
   str = _rawtostring(value)
   if typica == "metatable" then
      str = "⟨" .. "mt:" .. str:sub(-6) .. "⟩"
   elseif typica == "table" then
      str = "t:" .. str:sub(-6)
   elseif typica == "function" then
      local f_label = str:sub(11)
      str = f_label:sub(1,5) == "built"
                and f_label
                or "f:" .. str:sub(-6)
   elseif typica == "thread" then
      str = "coro:" .. str:sub(-6)
   elseif typica == "userdata" then
      local name_end = str:find(":")
      if name_end then
         str = str:sub(1, name_end - 1)
      end
   end

   return Token(str, color, cfg)
end


















local function c_data(value, str, phrase)
   --local meta = reflect.getmetatable(value)
   yield(str, #str)
   --[[
   if meta then
      yield(c.base " = ", 3)
      yield_name(meta)
   end
   --]]
end



return names
