---@namespace HorseMod

---REQUIREMENTS
local Mounts = require("HorseMod/Mounts")
local AnimationEvent = require("HorseMod/definitions/AnimationEvent")

local IS_SERVER = isServer()

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
---@field shouldFlee boolean
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

function UrgentDismountAction:animEvent(event, parameter)
    if self.shouldFlee and event == AnimationEvent.HORSE_FLEE then
        if IS_SERVER then
            ---@TODO to implement
        else
            local animal = self.animal
            animal:getBehavior():forceFleeFromChr(self.character)
        end
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
    -- character:setBlockMovement(true)
    character:setIgnoreInputsForDirection(true)
    character:setAuthorizedHandToHandAction(false)

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
    character:setAuthorizedHandToHandAction(true)
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
---@param shouldFlee boolean Whenever the horse should flee after dismounting
---@return self
---@nodiscard
function UrgentDismountAction:new(
    character, 
    animal, 
    dismountVariable, 
    horseSound, 
    playerVoice, 
    shouldFlee)
    ---@type UrgentDismountAction
    local o = ISBaseTimedAction.new(self, character)

    o.character = character
    o.animal = animal
    o.dismountVariable = dismountVariable
    o.horseSound = horseSound
    o.playerVoice = playerVoice
    o.shouldFlee = shouldFlee
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