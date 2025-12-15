require("TimedActions/ISBaseTimedAction")

local MountPair = require("HorseMod/MountPair")
local AnimationVariables = require("HorseMod/AnimationVariables")


---@namespace HorseMod


---@class MountHorseAction : ISBaseTimedAction
---
---@field pair MountPair
---
---@field horse IsoAnimal
---
---@field side "left" | "right"
---
---@field saddle InventoryItem | nil
---
---@field lockDir IsoDirections
local MountHorseAction = ISBaseTimedAction:derive("HorseMod_MountHorseAction")


---@return boolean
function MountHorseAction:isValid()
    if 
        self.horse and self.horse:isExistInTheWorld()
        and self.character and self.character:getSquare()
    then
        return true
    else
        return false
    end
end


function MountHorseAction:update()
    assert(self.lockDir ~= nil)
    self.horse:setDir(self.lockDir)
    self.character:setDir(self.lockDir)

    if self.character:getVariableBoolean(AnimationVariables.MOUNT_FINISHED) == true then
        self.character:setVariable(AnimationVariables.MOUNT_FINISHED, false)
        self:forceComplete()
    end
end


function MountHorseAction:start()
    -- freeze horse and log horse facing direction
    self.horse:getPathFindBehavior2():reset()
    self.horse:getBehavior():setBlockMovement(true)
    self.horse:stopAllMovementNow()

    self.horse:setVariable(AnimationVariables.DYING, false)

    self.lockDir = self.horse:getDir()
    self.character:setDir(self.lockDir)

    self.character:setVariable(AnimationVariables.MOUNTING_HORSE, true)
    self.character:setVariable(AnimationVariables.MOUNT_FINISHED, false)
    self.character:setVariable(AnimationVariables.DYING, false)

    if self.side == "right" then
        if self.saddle then
            self:setActionAnim("Bob_Mount_Saddle_Right")
        else
            self:setActionAnim("Bob_Mount_Bareback_Right")
        end
    end

    if self.side == "left" then
        if self.saddle then
            self:setActionAnim("Bob_Mount_Saddle_Left")
        else
            self:setActionAnim("Bob_Mount_Bareback_Left")
        end
    end
end


function MountHorseAction:stop()
    self.horse:getBehavior():setBlockMovement(false)

    self.pair:setAnimationVariable(AnimationVariables.RIDING_HORSE, false)
    self.character:setVariable(AnimationVariables.MOUNTING_HORSE, false)
    self.character:setVariable("isTurningLeft", false)
    self.character:setVariable("isTurningRight", false)
    self.character:setTurnDelta(1)

    self.character:setVariable(AnimationVariables.MOUNTING_HORSE, false)

    ISBaseTimedAction.stop(self)
end


function MountHorseAction:complete()
    -- HACK: we can't require this at file load because it is in the client dir
    --  this one definitely needs to be fixed but it requires tearing up half the mod
    require("HorseMod/Riding").createMountFromPair(self.pair)
    require("HorseMod/Mounts").addMount(self.character, self.horse)
    return true
end


function MountHorseAction:perform()
    -- HACK: we can't require this at file load because it is in the client dir
    require("HorseMod/Sounds").playMountSnort(self.character, self.horse)

    ISBaseTimedAction.perform(self)
end


function MountHorseAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end

    return -1
end


---@param pair MountPair
---@param side "left" | "right"
---@param saddle InventoryItem | nil
---@return self
---@nodiscard
function MountHorseAction:new(pair, side, saddle)
    ---@type MountHorseAction
    local o = ISBaseTimedAction.new(self, pair.rider)

    -- HACK: this loses its metatable when transmitted by the server
    setmetatable(pair, MountPair)
    o.pair = pair
    o.horse = pair.mount
    o.side = side
    o.saddle = saddle
    o.stopOnWalk = true
    o.stopOnRun  = true

    o.maxTime = o:getDuration()

    return o
end


_G[MountHorseAction.Type] = MountHorseAction


return MountHorseAction