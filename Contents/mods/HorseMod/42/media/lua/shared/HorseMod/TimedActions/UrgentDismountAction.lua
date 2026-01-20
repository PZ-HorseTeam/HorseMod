---@namespace HorseMod

---REQUIREMENTS
local AnimationVariable = require("HorseMod/AnimationVariable")
local Mounts = require("HorseMod/Mounts")

---@class UrgentDismountAction : ISBaseTimedAction
---
---@field character IsoPlayer
---
---@field animal IsoAnimal
---
---@field mount Mount
---
---@field dismountVariable AnimationVariable
---
---@field hasSaddle boolean
local UrgentDismountAction = ISBaseTimedAction:derive("HorseMod_UrgentDismountAction")

function UrgentDismountAction:isValid()
    return true
end

function UrgentDismountAction:update()
    local character = self.character

    -- keeps the player in position
    character:setDirectionAngle(self.lockDir)

    -- complete when mounting dying animation is finished
    if character:getVariableBoolean(self.dismountVariable) == false then
        self:forceComplete()
    end
end


function UrgentDismountAction:start()
    local character = self.character

    -- start animation
    character:setVariable(self.dismountVariable, true)

    -- lock player movement
    self.lockDir = self.animal:getDirectionAngle()
    character:setBlockMovement(true)
    character:setIgnoreInputsForDirection(true)

    -- drop heavy items
    character:dropHeavyItems()

    -- unmount
    Mounts.removeMount(character)
end

function UrgentDismountAction:stop()
    self:resetCharacterState()
    ISBaseTimedAction.stop(self)
end

function UrgentDismountAction:complete()
    self:resetCharacterState()
    return true
end

-- function UrgentDismountAction:perform()
--     ISBaseTimedAction.perform(self)
-- end

function UrgentDismountAction:resetCharacterState()
    local character = self.character
    character:setIgnoreMovement(false)
    character:setBlockMovement(false)
    character:setIgnoreInputsForDirection(false)
end

function UrgentDismountAction:getDuration()
    return -1
end

---@param character IsoPlayer
---@param animal IsoAnimal
---@param dismountVariable AnimationVariable?
---@return self
---@nodiscard
function UrgentDismountAction:new(character, animal, dismountVariable)
    ---@type UrgentDismountAction
    local o = ISBaseTimedAction.new(self, character)

    o.character = character
    o.animal = animal
    o.dismountVariable = dismountVariable or AnimationVariable.DYING

    -- we manually lock the player in place
    o.stopOnWalk = false
    o.stopOnRun = false
    o.stopOnAim = false

    o.maxTime = o:getDuration()
    o.useProgressBar = false

    return o
end

_G[UrgentDismountAction.Type] = UrgentDismountAction

return UrgentDismountAction