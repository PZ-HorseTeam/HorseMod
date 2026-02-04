local MountController = require("HorseMod/mount/MountController")
local AnimationVariable = require('HorseMod/definitions/AnimationVariable')
local InputManager = require("HorseMod/mount/InputManager")
local ReinsManager = require("HorseMod/mount/ReinsManager")
local Mounting = require("HorseMod/Mounting")


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
local Mount = {}
Mount.__index = Mount


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
    self.controller:update(
        self.inputManager:getCurrentInput()
    )
    self.reinsManager:update()
end


function Mount:cleanup()
    self.pair:setAnimationVariable(AnimationVariable.RIDING_HORSE, false)
    self.pair:setAnimationVariable(AnimationVariable.TROT, false)

    local attached = self.pair.rider:getAttachedAnimals()
    attached:remove(self.pair.mount)
    self.pair.mount:getData():setAttachedPlayer(nil) ---@diagnostic disable-line technically can still pass nil

    self.pair.rider:setVariable(AnimationVariable.TROT, false)
    self.pair.rider:setVariable(AnimationVariable.DISMOUNT_STARTED, false)
    self.pair.rider:setAllowRun(true)
    self.pair.rider:setAllowSprint(true)
    self.pair.rider:setTurnDelta(1)
    self.pair.rider:setSneaking(false)
    self.pair.rider:setIgnoreAutoVault(false)

    self.pair.mount:setVariable("bPathfind", false)
    self.pair.mount:setVariable("animalWalking", false)
    self.pair.mount:setVariable("animalRunning", false)

    self.pair.rider:setVariable(AnimationVariable.MOUNTING_HORSE, false)
    self.pair.rider:setVariable("isTurningLeft", false)
    self.pair.rider:setVariable("isTurningRight", false)
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
    rider:setAllowRun(false)
    rider:setAllowSprint(false)

    rider:setTurnDelta(0.65)

    rider:setVariable("isTurningLeft", false)
    rider:setVariable("isTurningRight", false)

    local geneSpeed = mount:getUsedGene("speed"):getCurrentValue()
    rider:setVariable(AnimationVariable.GENE_SPEED, geneSpeed)

    mount:setVariable("bPathfind", false)
    mount:setVariable("animalWalking", false)
    mount:setVariable("animalRunning", false)

    -- TODO: is this even needed
    mount:setWild(false)

    local o = setmetatable(
        {
            pair = pair
        },
        Mount
    )

    o.controller = MountController.new(o)
    o.inputManager = InputManager.new(o)
    o.reinsManager = ReinsManager.new(o)

    return o
end


return Mount