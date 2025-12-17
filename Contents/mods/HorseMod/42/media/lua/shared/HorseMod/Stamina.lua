local AnimationVariables = require("HorseMod/AnimationVariables")

---@namespace HorseMod


local Stamina = {}

-- Tunables (percent points per second)
Stamina.MAX = 100
Stamina.MIN_RUN_PERCENT = 0.15

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
    local isGalloping = horse:getVariableBoolean(AnimationVariables.GALLOP)
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