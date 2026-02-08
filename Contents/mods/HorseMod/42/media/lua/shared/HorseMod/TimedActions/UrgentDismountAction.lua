---@namespace HorseMod

---REQUIREMENTS
local Mounts = require("HorseMod/Mounts")
local AnimationEvent = require("HorseMod/definitions/AnimationEvent")

---@class UrgentDismountAction : ISBaseTimedAction, umbrella.NetworkedTimedAction
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
    -- keeps the player in position
    self.character:setDirectionAngle(self.lockDir)
end

function UrgentDismountAction:serverStart()
    -- TODO time should depend on animation, but idk how long the other ones are

    ---@cast self.netAction -nil
    ---@diagnostic disable-next-line: param-type-mismatch
    emulateAnimEventOnce(self.netAction, 1200, AnimationEvent.DISMOUNTING_COMPLETE, nil)

    return true
end

function UrgentDismountAction:animEvent(event, parameter)
    if event == AnimationEvent.HORSE_FLEE and self.shouldFlee and not isClient() then
        self.animal:getBehavior():forceFleeFromChr(self.character)
    elseif event == AnimationEvent.DISMOUNTING_COMPLETE then
        if isServer() then
            ---@cast self.netAction -nil
            self.netAction:forceComplete()
        else
            self:forceComplete()
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
    character:setBlockMovement(true)
    character:setIgnoreInputsForDirection(true)
    character:setAuthorizedHandToHandAction(false)
    character:setIgnoreAimingInput(true)

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

function UrgentDismountAction:perform()
    self:resetCharacterState()
    ISBaseTimedAction.perform(self)
end

function UrgentDismountAction:resetCharacterState()
    local character = self.character
    character:setIgnoreMovement(false)
    character:setBlockMovement(false)
    character:setIgnoreInputsForDirection(false)
    character:setAuthorizedHandToHandAction(true)
    character:setIgnoreAimingInput(false)
end

function UrgentDismountAction:getDuration()
    if not self.dismountVariable then
        return 100
    end

    return -1
end

---@param character IsoPlayer
---@param animal IsoAnimal
---@param dismountType AnimationVariable?
---@param horseSound Sound? The sound to play from the horse when dismounting
---@param playerVoice string? The voice ID to play when dismounting
---@param shouldFlee boolean Whenever the horse should flee after dismounting
---@return self
---@nodiscard
function UrgentDismountAction:new(
    character, 
    animal, 
    dismountType, 
    horseSound, 
    playerVoice, 
    shouldFlee)
    ---@type UrgentDismountAction
    local o = ISBaseTimedAction.new(self, character)

    o.character = character
    o.animal = animal
    o.dismountVariable = dismountType
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