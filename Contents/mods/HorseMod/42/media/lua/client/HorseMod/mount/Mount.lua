local MountController = require("HorseMod/mount/MountController")
local HorseDamage = require("HorseMod/horse/HorseDamage")
local HorseUtils = require("HorseMod/Utils")
local AnimationVariables = require("HorseMod/AnimationVariables")
local InputManager = require("HorseMod/mount/InputManager")


---@namespace HorseMod


---Main handler of player mounting horse state.
---@class Mount
---
---@field pair MountPair
---
---@field inputManager InputManager
---
---@field controller MountController
local Mount = {}
Mount.__index = Mount


---@param key integer
function Mount:keyPressed(key)
    self.inputManager:keyPressed(key)
end


---@return boolean
---@nodiscard
function Mount:dying()
    if self.pair.mount:getVariableBoolean(AnimationVariables.DYING) then
        self.pair.rider:setIgnoreMovement(true)
        self.pair.rider:setBlockMovement(true)
        self.pair.rider:setIgnoreInputsForDirection(true)
        self.pair.rider:setVariable(AnimationVariables.DYING, true)
        HorseUtils.runAfter(0.5, function()
            HorseDamage.knockDownNearbyZombies(self.pair.mount)
        end)
        return true
    else
        return false
    end
end


function Mount:update()
    if self.pair.mount and self:dying() then
        return
    end
    self.controller:update(
        self.inputManager:getCurrentInput()
    )
end


function Mount:cleanup()
    self.pair:setAnimationVariable(AnimationVariables.RIDING_HORSE, false)
    self.pair:setAnimationVariable(AnimationVariables.TROT, false)

    local attached = self.pair.rider:getAttachedAnimals()
    attached:remove(self.pair.mount)
    self.pair.mount:getData():setAttachedPlayer(nil)

    self.pair.mount:getBehavior():setBlockMovement(false)
    self.pair.mount:getPathFindBehavior2():reset()

    self.pair.rider:setVariable(AnimationVariables.TROT, false)
    self.pair.rider:setVariable(AnimationVariables.DISMOUNT_STARTED, false)
    self.pair.rider:setAllowRun(true)
    self.pair.rider:setAllowSprint(true)
    self.pair.rider:setTurnDelta(1)
    self.pair.rider:setSneaking(false)
    self.pair.rider:setIgnoreAutoVault(false)

    self.pair.mount:setVariable("bPathfind", false)
    self.pair.mount:setVariable("animalWalking", false)
    self.pair.mount:setVariable("animalRunning", false)

    self.pair.rider:setVariable(AnimationVariables.MOUNTING_HORSE, false)
    self.pair.rider:setVariable("isTurningLeft", false)
    self.pair.rider:setVariable("isTurningRight", false)
end


---@param pair MountPair
---@return Mount
---@nodiscard
function Mount.new(pair)
    pair.rider:getAttachedAnimals():add(pair.mount)
    pair.mount:getData():setAttachedPlayer(pair.rider)

    pair:setAnimationVariable(AnimationVariables.RIDING_HORSE, true)
    pair:setAnimationVariable(AnimationVariables.TROT, false)
    pair.rider:setAllowRun(false)
    pair.rider:setAllowSprint(false)

    pair.rider:setTurnDelta(0.65)

    pair.rider:setVariable("isTurningLeft", false)
    pair.rider:setVariable("isTurningRight", false)

    local geneSpeed = pair.mount:getUsedGene("speed"):getCurrentValue()
    pair.rider:setVariable(AnimationVariables.GENE_SPEED, geneSpeed)

    pair.mount:getPathFindBehavior2():reset()
    pair.mount:getBehavior():setBlockMovement(true)
    pair.mount:stopAllMovementNow()

    pair.mount:setVariable("bPathfind", false)
    pair.mount:setVariable("animalWalking", false)
    pair.mount:setVariable("animalRunning", false)

    -- TODO: are these even needed
    pair.mount:setWild(false)
    pair.mount:setVariable(AnimationVariables.IS_HORSE, true)

    local o = setmetatable(
        {
            pair = pair
        },
        Mount
    )

    o.controller = MountController.new(o)
    o.inputManager = InputManager.new(o)

    return o
end


return Mount