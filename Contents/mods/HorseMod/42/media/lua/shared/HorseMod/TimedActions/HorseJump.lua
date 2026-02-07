---@namespace HorseMod

---REQUIREMENTS
local AnimationVariable = require("HorseMod/definitions/AnimationVariable")
local AnimationEvent = require("HorseMod/definitions/AnimationEvent")

---@class HorseJump : ISBaseTimedAction
---@field animal IsoAnimal
---@field controller MountController
local HorseJump = ISBaseTimedAction:derive("HorseMod_HorseJump")

function HorseJump:isValid()
    return true
end

function HorseJump:animEvent(event, parameter)
    if event == AnimationEvent.JUMP_END then
        if isServer() then
            ---@diagnostic disable-next-line: need-check-nil
            self.netAction:forceComplete()
        else
            self:forceComplete()
        end
    end
end

function HorseJump:start()
    local character = self.character
    local controller = self.controller
    local pair = controller.mount.pair

    -- limit movements of player and animal during the jump
    pair:setAnimationVariable(AnimationVariable.JUMP, true)
    character:setIgnoreMovement(true)
    character:setIgnoreInputsForDirection(true)
    character:setIgnoreAimingInput(true)
    character:setIsAiming(false)

    controller.doTurn = false
    controller.forcedInput = controller.mount.inputManager:getCurrentInput()
end

function HorseJump:stop()
    self:resetCharacterState()
    ISBaseTimedAction.stop(self)
end

function HorseJump:complete()
    self:resetCharacterState()
    return true
end

function HorseJump:resetCharacterState()
    local character = self.character
    local controller = self.controller
    local pair = controller.mount.pair
    
    character:setIgnoreMovement(false)
    character:setIgnoreInputsForDirection(false)
    character:setIgnoreAimingInput(false)

    pair:setAnimationVariable(AnimationVariable.JUMP, false)
    
    controller.doTurn = true
    controller.forcedInput = nil
end


function HorseJump:getDuration()
    return -1
end


---@param character IsoPlayer
---@param animal IsoAnimal
---@param controller MountController
function HorseJump:new(character, animal, controller)
    ---@type HorseJump
    local o = ISBaseTimedAction.new(self, character)

    o.character = character
    o.animal = animal
    o.controller = controller
    o.maxTime = o:getDuration()

    o.stopOnWalk = false
    o.stopOnRun = false
    o.stopOnAim = false
    o.useProgressBar = false

    return o
end


_G[HorseJump.Type] = HorseJump

return HorseJump