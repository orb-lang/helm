# Names

Provides a consistent notion of the "name" of a value.

## Dependencies

```lua
local Token = require "helm/repr/token"
```
## Setup

```lua
local names = {}
```
### anti_G

In order to provide names for values, we want to trawl through ``_G`` and
acquire them.  This table is from value to key where ``_G`` is key to value,
hence, ``anti_G``.

```lua
local anti_G = { _G = "_G" }
```

Now to populate it:


### names.allNames()

Ransacks ``_G`` looking for names to put on things.


To really dig out a good name for metatables we're going to need to write
some kind of reflection function that will dig around in upvalues to find
local names for things.


#### tie_break(old, new)

A helper function to decide which name is better.

```lua
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
            (type(k) == "string" and k or "<" .. tostring(k) .. ">")
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
               aG[_M] = _M_id
               addName(_M, aG, _M_id)
            else
               local aG_M_id = aG[_M]
               if tie_break(aG_M_id, _M_id) then
                  aG[_M] = _M_id
                  addName(_M, aG, _M_id)
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
names.addName = addName
```
#### names.allNames(), names.clearNames()

The trick here is that we scan ``package.loaded`` after ``_G``, which gives
better names for things.

```lua
function names.allNames(tab)
   tab = tab or _G
   return addName(package.loaded, addName(tab))
end

function names.clearNames()
   anti_G = {_G = "_G"}
   return anti_G
end
```
### names.nameFor(value, c, hint)

Generates a simple, name-like representation of ``value``. For simple types
(strings, numbers, booleans, nil) this is the stringified value itself.
For tables, functions, etc. attempts to retrieve a name from anti_G, falling
back to generating a name from the hash if none is found.


Lots of small, nice things in this one.

```lua

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

```
### cdata pretty-printing

Note: the reflect library appears to be broken for LuaJIT 2.1 so we're
not going to use it.


I'm leaving in the code for now, because I'd like to repair and use it...


lol

#Todo fix
yielding multiple tokens in this case.

```lua
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
```
```lua
return names
```