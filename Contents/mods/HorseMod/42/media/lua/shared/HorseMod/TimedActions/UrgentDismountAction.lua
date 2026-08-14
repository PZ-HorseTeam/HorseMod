---@namespace HorseMod

---REQUIREMENTS
local Mounts = require("HorseMod/Mounts")
local AnimationEvent = require("HorseMod/definitions/AnimationEvent")
local AnimationVariable = require("HorseMod/definitions/AnimationVariable")
local mountcommands = require("HorseMod/networking/mountcommands")
local commands = require("HorseMod/networking/commands")

---rider client can use the animation event to complete the dismount
---But the server must emulate it for remote clients, so it needs to be provided with the animation lengths
local FALL_BACK_DURATION_MS = 4300
local DYING_DURATION_MS = 5266

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

---@return boolean
function UrgentDismountAction:isValid()
    return true
end

function UrgentDismountAction:update()
    -- keeps the player in position
    self.character:setDirectionAngle(self.lockDir)
end

---Length of the fall/death animation in ms
---@return integer
function UrgentDismountAction:getAnimationDurationMS()
    if self.dismountVariable == AnimationVariable.DYING then
        return DYING_DURATION_MS
    end

    return FALL_BACK_DURATION_MS
end

---True for animations that visually require the rider to stay on the horse
---while playing, like the death animation
---@return boolean
function UrgentDismountAction:keepsRiderMounted()
    return self.dismountVariable == AnimationVariable.DYING
end


function UrgentDismountAction:broadcastUrgentDismount()
    if not self.dismountVariable then
        return
    end

    mountcommands.UrgentDismount:send(nil, {
        character = commands.getPlayerId(self.character),
        dismountType = self.dismountVariable,
    })
end

function UrgentDismountAction:serverStart()
    if not self:keepsRiderMounted() then
        Mounts.removeMount(self.character)
    end
    self:broadcastUrgentDismount()

    -- Emulate HorseDismountingComplete using the real animation length so the remote client sees it
    ---@cast self.netAction -nil
    ---@diagnostic disable-next-line: param-type-mismatch
    emulateAnimEventOnce(self.netAction, self:getAnimationDurationMS(), AnimationEvent.DISMOUNTING_COMPLETE, nil)

    return true
end

function UrgentDismountAction:animEvent(event, parameter)
    if event == AnimationEvent.DISMOUNTING_COMPLETE then
        if isServer() then
            ---@cast self.netAction -nil
            self.netAction:forceComplete()
        else
            self:forceComplete()
        end
    elseif event == AnimationEvent.HORSE_FLEE then
        if self.shouldFlee and self.animal then
            if isClient() then
                mountcommands.HorseFleeRequest:send(self.character, {
                    animal = commands.getAnimalId(self.animal),
                    character = commands.getPlayerId(self.character)
                })
            else
                self.animal:getBehavior():forceFleeFromChr(self.character)
            end
        end
    end
end


function UrgentDismountAction:start()
    local character = self.character
    local animal = self.animal

    if not self:keepsRiderMounted() then
        Mounts.removeMount(character)
    end

    -- start animation
    local dismountVariable = self.dismountVariable
    if dismountVariable then
        character:setVariable(dismountVariable, true)
    end

    -- lock player movement for the full animation; resetCharacterState (called
    -- from complete/perform/stop) reverses every one of these
    self.lockDir = character:getDirectionAngle()
    character:setBlockMovement(true)
    character:setIgnoreMovement(true)
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

    if isServer() then
        -- Listen host: start() runs here (there is no netAction/serverStart),
        -- so broadcast the animation to remote clients from here.
        self:broadcastUrgentDismount()
        return
    else
        local HorseSounds = require("HorseMod/HorseSounds")
        local horseSound = self.horseSound
        if horseSound then
            HorseSounds.playSound(animal, horseSound)
        end
    end
end

function UrgentDismountAction:stop()
    self:resetCharacterState()
    ISBaseTimedAction.stop(self)
end

function UrgentDismountAction:perform()
    self:resetCharacterState()
    ISBaseTimedAction.perform(self)
end

function UrgentDismountAction:complete()
    if Mounts.getMount(self.character) == self.animal then
        Mounts.removeMount(self.character)
    end

    self:resetCharacterState()
    return true
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
