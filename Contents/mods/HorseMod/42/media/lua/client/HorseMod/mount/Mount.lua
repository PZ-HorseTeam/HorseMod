local MountController = require("HorseMod/mount/MountController")
local AnimationVariable = require('HorseMod/definitions/AnimationVariable')
local InputManager = require("HorseMod/mount/InputManager")
local MountedAnimationState = require("HorseMod/riding/MountedAnimationState")
local ReinsManager = require("HorseMod/mount/ReinsManager")
local Mounting = require("HorseMod/Mounting")
local mountcommands = require("HorseMod/networking/mountcommands")
local commands = require("HorseMod/networking/commands")


---@namespace HorseMod


---Main handler of player mounting horse state.
---@class Mount
---
---@field pair MountPair
---
---@field inputManager InputManager
---
---@field controller MountController
---
---@field reinsManager ReinsManager
---@field inputSeq integer
---@field inputSendTimer number
---@field lastSentInput RidingMovementInput?
local Mount = {}
Mount.__index = Mount

local INPUT_SEND_INTERVAL = 0.05

---@param a RidingMovementInput
---@param b RidingMovementInput
---@return boolean
---@nodiscard
local function inputsEqual(a, b)
    return a.movement.x == b.movement.x
        and a.movement.y == b.movement.y
        and a.run == b.run
        and a.trot == b.trot
        and a.jump == b.jump
end

---@param input RidingMovementInput
---@return RidingMovementInput
---@nodiscard
local function copyInput(input)
    return {
        movement = {
            x = input.movement.x,
            y = input.movement.y,
        },
        run = input.run,
        trot = input.trot,
        jump = input.jump,
    }
end

---@param pair MountPair
---@param direction IsoDirections
local function holdRiderOnMount(pair, direction)
    local rider = pair.rider
    local mount = pair.mount

    rider:setSneaking(false)
    rider:setIgnoreMovement(true)
    rider:setIgnoreInputsForDirection(true)
    rider:setIgnoreAimingInput(true)
    rider:setIgnoreAutoVault(true)

    rider:setForceX(mount:getX())
    rider:setForceY(mount:getY())
    rider:setZ(mount:getZ())
end


---@param key integer
function Mount:keyPressed(key)
    self.inputManager:keyPressed(key)
end


---@return boolean
---@nodiscard
function Mount:isDying()
    if self.pair.mount:getVariableBoolean(AnimationVariable.DYING) then
        return true
    end
    return false
end

function Mount:update()
    if self:isDying() then
        Mounting.dismountDeath(self.pair.rider, self.pair.mount)
        return
    end
    local input = self.inputManager:getCurrentInput()

    if isClient() then
        local sentInput = copyInput(input)
        self.controller:update(input)
        self.reinsManager:update()
        holdRiderOnMount(self.pair, self.controller:getDirection())
        -- Keep input.jump=true for the entire local jump duration so the server
        -- doesn't flip it back to flase after one tick and remote clients doesn't see full jump
        if self.controller.movement:isJumping() then
            sentInput.jump = true
        end
        self:sendRidingInput(sentInput)
    elseif isServer() then
        return
    else
        self.controller:update(input)
        self.reinsManager:update()
    end
end

---@param input RidingMovementInput
function Mount:sendRidingInput(input)
    if isClient() then
        self.inputSendTimer = self.inputSendTimer + GameTime.getInstance():getTimeDelta()

        local changed = true
        if self.lastSentInput then
            changed = not inputsEqual(input, self.lastSentInput)
        end

        if changed or self.inputSendTimer >= INPUT_SEND_INTERVAL then
            self.inputSeq = self.inputSeq + 1
            self.inputSendTimer = 0
            self.lastSentInput = copyInput(input)

            mountcommands.RidingInput:send(
                self.pair.rider,
                {
                    animal = commands.getAnimalId(self.pair.mount),
                    seq = self.inputSeq,
                    moveX = input.movement.x,
                    moveY = input.movement.y,
                    run = input.run,
                    trot = input.trot,
                    jump = input.jump,
                    x = self.pair.mount:getX(),
                    y = self.pair.mount:getY(),
                    z = self.pair.mount:getZ(),
                    dir = self.controller:getDirection():ordinal(),
                    speed = self.controller:getCurrentSpeed(),
                    hasReins = self.pair.rider:getVariableBoolean(AnimationVariable.HAS_REINS),
                }
            )
        end
    elseif isServer() then
        return
    else
        return
    end
end

---@param args RidingStateArguments
function Mount:applyAuthoritativeState(args)
    self.controller:applyRecoveryState(args)
end


function Mount:cleanup()
    self.pair:setAnimationVariable(AnimationVariable.RIDING_HORSE, false)
    self.pair:setAnimationVariable(AnimationVariable.TROT, false)

    local attached = self.pair.rider:getAttachedAnimals()
    attached:remove(self.pair.mount)
    self.pair.mount:getData():setAttachedPlayer(nil) ---@diagnostic disable-line technically can still pass nil

    self.pair.rider:setVariable(AnimationVariable.TROT, false)
    self.pair.rider:setVariable(AnimationVariable.GALLOP, false)
    self.pair.rider:setVariable(AnimationVariable.JUMP, false)
    self.pair.rider:setVariable(AnimationVariable.HAS_REINS, false)
    self.pair.rider:setVariable(AnimationVariable.DISMOUNT_STARTED, false)
    self.pair.rider:setAllowRun(true)
    self.pair.rider:setAllowSprint(true)
    self.pair.rider:setTurnDelta(1)
    self.pair.rider:setSneaking(false)
    self.pair.rider:setIgnoreMovement(false)
    self.pair.rider:setIgnoreInputsForDirection(false)
    self.pair.rider:setIgnoreAimingInput(false)
    self.pair.rider:setIgnoreAutoVault(false)

    self.pair.mount:setVariable("bPathfind", false)
    MountedAnimationState.setMovementVariables(self.pair.rider, self.pair.mount, false, false)
    MountedAnimationState.setTurnVariables(self.pair.rider, self.pair.mount, 0)

    self.pair.rider:setVariable(AnimationVariable.MOUNTING_HORSE, false)
    self.pair.rider:setVariable(AnimationVariable.IS_TURNING_LEFT, false)
    self.pair.rider:setVariable(AnimationVariable.IS_TURNING_RIGHT, false)

end


---@param pair MountPair
---@return Mount
---@nodiscard
function Mount.new(pair)
    local rider = pair.rider
    local mount = pair.mount

    -- pair.rider:getAttachedAnimals():add(pair.mount)
    -- pair.mount:getData():setAttachedPlayer(pair.rider)

    pair:setAnimationVariable(AnimationVariable.RIDING_HORSE, true)
    pair:setAnimationVariable(AnimationVariable.TROT, false)
    pair:setAnimationVariable(AnimationVariable.GALLOP, false)
    pair:setAnimationVariable(AnimationVariable.IS_TURNING_LEFT, false)
    pair:setAnimationVariable(AnimationVariable.IS_TURNING_RIGHT, false)
    pair:setAnimationVariable(AnimationVariable.IS_TURNING, false)
    
    rider:setAllowRun(false)
    rider:setAllowSprint(false)
    rider:setIgnoreMovement(true)
    rider:setIgnoreInputsForDirection(true)
    rider:setIgnoreAimingInput(true)

    rider:setTurnDelta(0.65)

    local geneSpeed = mount:getUsedGene("speed"):getCurrentValue()
    MountedAnimationState.setSpeedVariables(rider, mount, geneSpeed)

    mount:setVariable("bPathfind", false)
    MountedAnimationState.setMovementVariables(rider, mount, false, false)

    -- TODO: is this even needed
    mount:setWild(false)

    local o = setmetatable(
        {
            pair = pair,
            inputSeq = 0,
            inputSendTimer = INPUT_SEND_INTERVAL,
            lastSentInput = nil
        },
        Mount
    )

    o.controller = MountController.new(o)
    o.inputManager = InputManager.new(o)
    o.reinsManager = ReinsManager.new(o)

    return o
end


return Mount
