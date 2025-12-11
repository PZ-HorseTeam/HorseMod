local HorseManager = require("HorseMod/HorseManager")


---@namespace HorseMod


local Stamina = {}

-- Tunables (percent points per second)
Stamina.MAX            = 100
Stamina.DRAIN_RUN      = 4      -- while galloping
Stamina.REGEN_TROT     = 1.5     -- moving w/ HorseTrot true
Stamina.REGEN_WALK     = 3.0     -- moving but not running/trotting
Stamina.REGEN_IDLE     = 6.0     -- standing still
Stamina.MIN_RUN_PERCENT = 0.15


---@param x number
---@param a number
---@param b number
---@return number
---@nodiscard
local function clamp(x, a, b)
    return (x < a) and a
        or ((x > b) and b or x)
end


---@param horse IsoAnimal
---@return number
function Stamina.get(horse)
    local modData = horse:getModData()
    if modData.HorseMod_Stamina == nil then
        modData.HorseMod_Stamina = Stamina.MAX
        horse:transmitModData()
    end
    return modData.HorseMod_Stamina
end


---@param horse IsoAnimal
---@param value number
---@param transmit boolean
---@return number
function Stamina.set(horse, value, transmit)
    local modData = horse:getModData()
    local newValue = clamp(value, 0, Stamina.MAX)

    if modData.HorseMod_Stamina ~= newValue then
        modData.HorseMod_Stamina = newValue
        if transmit then
            horse:transmitModData()
        end
    end

    return newValue
end


---@param horse IsoAnimal
---@param valueDelta number
---@param transmit boolean
---@return number stamina The horse's new stamina level
function Stamina.modify(horse, valueDelta, transmit)
    return Stamina.set(horse, Stamina.get(horse) + valueDelta, transmit)
end


---@param horse IsoAnimal
---@return number
---@nodiscard
function Stamina.runSpeedFactor(horse)
    local stamina = Stamina.get(horse) / Stamina.MAX
    if stamina >= 0.5 then
        return 1.0
    end
    local t = stamina / 0.5
    return t * t
end


---@param horse IsoAnimal
---@param input MountController.Input
---@param moving boolean
---@return boolean
---@nodiscard
function Stamina.shouldRun(horse, input, moving)
    local stamina = Stamina.get(horse)
    local minRunStamina = Stamina.MAX * Stamina.MIN_RUN_PERCENT
    local wantsRun = input.run and true or false
    local runAllowed = false
    local isGalloping = horse:getVariableBoolean("HorseGallop")
    local needsStaminaRecovery = false

    if isGalloping then
        -- In some cases the stamina bottoms out at 0.05
        if wantsRun and moving and stamina >= 0.1 then
            runAllowed = true
        else
            isGalloping = false
            if stamina <= minRunStamina then
                needsStaminaRecovery = true
            end
        end
    end

    if not isGalloping then
        if needsStaminaRecovery and stamina >= minRunStamina then
            needsStaminaRecovery = false
        end

        if wantsRun and moving and not needsStaminaRecovery and stamina >= minRunStamina then
            isGalloping = true
            runAllowed = true
        end
    end
    return runAllowed
end


---@class StaminaSystem : System
local StaminaSystem = {}


function StaminaSystem:update(horses, delta)
    for i = 1, #horses do
        local horse = horses[i]
        -- TODO: exclude mounted horses

        local regenRate = horse:isAnimalMoving() and Stamina.REGEN_WALK or Stamina.REGEN_IDLE
        -- TODO: it's unideal that we transmit the stamina of horses constantly
        Stamina.modify(horse, regenRate * delta, true)
    end
end


table.insert(HorseManager.systems, StaminaSystem)


return Stamina