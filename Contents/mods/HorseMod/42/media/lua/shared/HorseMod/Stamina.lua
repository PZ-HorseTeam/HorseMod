local HorseRiding = require("HorseMod/Riding")
local HorseManager = require("HorseMod/HorseManager")


local Stamina = {}

-- Tunables (percent points per second)
Stamina.MAX            = 100
Stamina.DRAIN_RUN      = 6      -- while galloping
Stamina.REGEN_TROT     = 1.5     -- moving w/ HorseTrot true
Stamina.REGEN_WALK     = 3.0     -- moving but not running/trotting
Stamina.REGEN_IDLE     = 6.0     -- standing still

Stamina.REGEN_SPEED = 0.3

local function clamp(x, a, b)
    return (x < a) and a 
        or ((x > b) and b or x)
end

---@param horse IsoAnimal
---@return number
function Stamina.get(horse)
    local md = horse:getModData()
    if md.hm_stam == nil then
        md.hm_stam = Stamina.MAX
        horse:transmitModData()
    end
    return md.hm_stam
end


---@param horse IsoAnimal
---@param v number
---@param transmit boolean
function Stamina.set(horse, v, transmit)
    local md = horse:getModData()
    local nv = clamp(v, 0, Stamina.MAX)
    if md.hm_stam ~= nv then
        md.hm_stam = nv
        if transmit and horse.transmitModData then horse:transmitModData() end
    end
    return nv
end


---@param horse IsoAnimal
---@param v number
---@param transmit boolean
function Stamina.modify(horse, dv, transmit)
    return Stamina.set(horse, Stamina.get(horse) + dv, transmit)
end


---@param horse IsoAnimal
---@return number
---@nodiscard
function Stamina.runSpeedFactor(horse)
    local s = Stamina.get(horse) / Stamina.MAX
    if s >= 0.5 then
        return 1.0
    end
    local t = s / 0.5
    return t * t
end


---@param horse IsoAnimal
---@return boolean
---@nodiscard
function Stamina.canRun(horse)
    return Stamina.get(horse) > 10.0
end


---@class StaminaSystem : HorseMod.System
local StaminaSystem = {}


function StaminaSystem:update(horses, delta)
    for i = 1, #horses do
        local horse = horses[i]

        local regenRate = horse:isAnimalMoving() and Stamina.REGEN_WALK or Stamina.REGEN_IDLE
        -- TODO: it's unideal that we transmit the stamina of horses constantly
        Stamina.modify(horse, regenRate * delta, true)
    end
end


table.insert(HorseManager.systems, StaminaSystem)


return Stamina