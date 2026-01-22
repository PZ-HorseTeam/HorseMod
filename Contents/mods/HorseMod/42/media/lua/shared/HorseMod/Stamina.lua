local AnimationVariable = require('HorseMod/definitions/AnimationVariable')
local HorseModData = require("HorseMod/HorseModData")

---@namespace HorseMod


local Stamina = {
    -- Tunables (percent points per second)
    MAX = 100,
    MIN_RUN_PERCENT = 0.15,
    
}

Stamina.StaminaChange = {
    -- while galloping
    RUN = -4,
    -- moving w/ HorseTrot true
    TROT = 1.5,
    -- moving but not running/trotting
    WALK = 3.0,
    -- standing still
    IDLE = 6.0
}


---Persistent stamina data for the horse.
---@class StaminaModData
---@field stamina number

local STAMINA_MOD_DATA = HorseModData.register--[[@<StaminaModData>]](
    "stamina",
    function(horse, modData)
        modData.stamina = modData.stamina or Stamina.MAX
    end
)
Stamina.STAMINA_MOD_DATA = STAMINA_MOD_DATA


---@param x number
---@param a number
---@param b number
---@return number
---@nodiscard
local function clamp(x, a, b)
    return (x < a) and a
        or ((x > b) and b or x)
end


---Retrieves the current stamina of the horse.
---@param horse IsoAnimal
---@return number stamina
function Stamina.get(horse)
    local modData = HorseModData.get(horse, STAMINA_MOD_DATA)
    return modData.stamina
end


---Set the stamina of the horse. The value will be clamped between `0` and :lua:obj:`HorseMod.Stamina.MAX`.
---@param horse IsoAnimal
---@param value number
---@param transmit boolean
---@return number
function Stamina.set(horse, value, transmit)
    local modData = HorseModData.get(horse, STAMINA_MOD_DATA)
    local newValue = clamp(value, 0, Stamina.MAX)

    if modData.stamina ~= newValue then
        modData.stamina = newValue
        if transmit then
            horse:transmitModData()
        end
    end

    return newValue
end


---Modifies the stamina of the horse by the given delta. The resulting value will be clamped between `0` and :lua:obj:`HorseMod.Stamina.MAX`.
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
---@param input InputManager.Input
---@param moving boolean
---@return boolean
---@nodiscard
function Stamina.shouldRun(horse, input, moving)
    local stamina = Stamina.get(horse)
    local minRunStamina = Stamina.MAX * Stamina.MIN_RUN_PERCENT
    local wantsRun = input.run and true or false
    local runAllowed = false
    local isGalloping = horse:getVariableBoolean(AnimationVariable.GALLOP)
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


return Stamina