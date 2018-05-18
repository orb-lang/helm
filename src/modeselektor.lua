
















































assert(meta, "must have meta in _G")
local ModeS = meta()
assert(write, "must have write in G")
local unpack = assert(unpack)








local INSERT = {}
local NAV    = {}
local CTRL   = {}
local ALT    = {}
local FN     = {}
local MOUSE  = {}






















ModeS.modes = { INSERT = INSERT,
                NAV    = NAV,
                CTRL   = CTRL,
                ALT    = ALT,
                MOUSE  = MOUSE }






ModeS.special = {}















function ModeS.act(modeS, category, value)
   if modeS.special[value] then
      return modeS.special[value](modeS, category, value)
   elseif modeS.modes[category][value] then
      return modeS.modes[category][value](modeS, category, value)
   else
      return modeS:default(category, value)
   end
end



function ModeS.default(modeS, category, value)
    return write(value)
end





function new()
  local modeS = meta(ModeS)
  return modeS
end

ModeS.idEst = new



return new
