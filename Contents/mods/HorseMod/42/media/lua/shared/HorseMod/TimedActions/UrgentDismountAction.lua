---@namespace HorseMod

---REQUIREMENTS
local AnimationVariable = require('HorseMod/definitions/AnimationVariable')
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
---
---@field horseSound Sound
---
---@field playerVoice string
---
---@field shouldWander boolean
local UrgentDismountAction = ISBaseTimedAction:derive("HorseMod_UrgentDismountAction")

function UrgentDismountAction:isValid()
    return true
end

function UrgentDismountAction:update()
    local character = self.character

    -- keeps the player in position
    character:setDirectionAngle(self.lockDir)

    -- complete when mounting dying animation is finished
    local dismountVariable = self.dismountVariable
    if dismountVariable and character:getVariableBoolean(dismountVariable) == false then
        self:forceComplete()
    end
end


function UrgentDismountAction:start()
    local character = self.character
    local animal = self.animal

    -- start animation
    local dismountVariable = self.dismountVariable
    if dismountVariable then
        character:setVariable(dismountVariable, true)
    end

    -- lock player movement
    self.lockDir = animal:getDirectionAngle()
    character:setBlockMovement(true)
    character:setIgnoreInputsForDirection(true)

    -- drop heavy items
    character:dropHeavyItems()

    -- play hurting sound based on dismount type
    local playerVoice = self.playerVoice
    if playerVoice then
        character:playerVoiceSound(playerVoice)
    end

    -- play horse hurting sound
    local HorseSounds = require("HorseMod/HorseSounds")
    local horseSound = self.horseSound
    if horseSound then
        HorseSounds.playSound(animal, horseSound)
    end

    -- unmount
    Mounts.removeMount(character)
end

function UrgentDismountAction:stop()
    self:resetCharacterState()
    ISBaseTimedAction.stop(self)
end

function UrgentDismountAction:complete()
    self:resetCharacterState()

    ---@TODO need to make the horse move before the end since the complete triggers only when the player falling animation ends
    ---possibly do that with a variable being set in the anim node
    ---or make the falling animations make the player fall fast enough so it looks natural
    if self.shouldWander then
        local animal = self.animal
        animal:setVariable("animalRunning", true)
        animal:forceWanderNow()
    end
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
    if self.dismountVariable then
        return -1
    end
    return 100
end

---@param character IsoPlayer
---@param animal IsoAnimal
---@param dismountVariable AnimationVariable?
---@param horseSound Sound? The sound to play from the horse when dismounting
---@param playerVoice string? The voice ID to play when dismounting
---@param shouldWander boolean Whenever the horse should wander after dismounting
---@return self
---@nodiscard
function UrgentDismountAction:new(
    character, 
    animal, 
    dismountVariable, 
    horseSound, 
    playerVoice, 
    shouldWander)
    ---@type UrgentDismountAction
    local o = ISBaseTimedAction.new(self, character)

    o.character = character
    o.animal = animal
    o.dismountVariable = dismountVariable
    o.horseSound = horseSound
    o.playerVoice = playerVoice
    o.shouldWander = shouldWander
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