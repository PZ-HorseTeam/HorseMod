if isClient() then
    return
end

local Stamina = require("HorseMod/Stamina")
local Mounts = require("HorseMod/Mounts")
local HorseManager = require("HorseMod/HorseManager")
local AnimationVariable = require('HorseMod/definitions/AnimationVariable')

local StaminaChange = Stamina.StaminaChange

---@namespace HorseMod


---@class StaminaSystem : System
local StaminaSystem = {}


function StaminaSystem:update(horses, delta)
    for i = 1, #horses do
        local horse = horses[i]

        local staminaChange = 0.0
        if Mounts.hasRider(horse) then
            if horse:getMovementSpeed() >= 0.01 then
                if horse:getVariableBoolean(AnimationVariable.GALLOP) then
                    staminaChange = StaminaChange.RUN
                elseif horse:getVariableBoolean(AnimationVariable.TROT) then
                    staminaChange = StaminaChange.TROT
                else
                    staminaChange = StaminaChange.WALK
                end
            else
                staminaChange = StaminaChange.IDLE
            end
        else
            staminaChange = horse:getMovementSpeed() >= 0.01 and StaminaChange.WALK or StaminaChange.IDLE
        end

        if staminaChange > 0 then
            staminaChange = staminaChange * SandboxVars.HorseMod.StaminaMultiplier
        else
            staminaChange = staminaChange / SandboxVars.HorseMod.StaminaMultiplier
        end

        -- TODO: it might be better to transmit this less often
        Stamina.modify(horse, staminaChange * delta, true)
    end
end


table.insert(HorseManager.systems, StaminaSystem)


return StaminaSystem