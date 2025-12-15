local Stamina = require("HorseMod/Stamina")
local Mounts = require("HorseMod/Mounts")
local HorseManager = require("HorseMod/HorseManager")
local AnimationVariables = require("HorseMod/AnimationVariables")

local StaminaChange = Stamina.StaminaChange

---@namespace HorseMod


---@class StaminaSystem : System
local StaminaSystem = {}


function StaminaSystem:update(horses, delta)
    for i = 1, #horses do
        local horse = horses[i]

        local staminaChange = 0.0
        if Mounts.mountPlayerMap[horse] then
            if horse:isAnimalMoving() then
                if horse:getVariableBoolean(AnimationVariables.GALLOP) then
                    staminaChange = StaminaChange.RUN
                elseif horse:getVariableBoolean(AnimationVariables.TROT) then
                    staminaChange = StaminaChange.TROT
                else
                    staminaChange = StaminaChange.WALK
                end
            else
                staminaChange = StaminaChange.IDLE
            end
        else
            staminaChange = horse:isAnimalMoving() and StaminaChange.WALK or StaminaChange.IDLE
        end

        -- TODO: it might be better to transmit this less often
        Stamina.modify(horse, staminaChange * delta, true)
    end
end


table.insert(HorseManager.systems, StaminaSystem)


return StaminaSystem