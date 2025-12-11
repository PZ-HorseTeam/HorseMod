require("TimedActions/ISBaseTimedAction")

local HorseRiding = require("HorseMod/Riding")


---@namespace HorseMod


---@class DismountHorseAction : ISBaseTimedAction
---
---@field character IsoPlayer
---
---@field horse IsoAnimal
---
---@field mount Mount
---
---@field _lockDir IsoDirections | nil
---
---@field side "left" | "right"
---
---@field saddle boolean
---
---@field landX number
---
---@field landY number
---
---@field landZ number
local DismountHorseAction = ISBaseTimedAction:derive("DismountHorseAction")


---@return boolean
function DismountHorseAction:isValid()
    return self.horse:isExistInTheWorld()
           and self.character:getAttachedAnimals():contains(self.horse) or false
end


function DismountHorseAction:update()
    assert(self._lockDir ~= nil)

    -- keep the horse locked facing the stored direction
    self.horse:setDir(self._lockDir)

    if self.character:getVariableBoolean("DismountFinished") == true then
        self.character:setVariable("DismountFinished", false)
        self:forceComplete()
    end
end


function DismountHorseAction:start()
    self.horse:getPathFindBehavior2():reset()
    self.horse:getBehavior():setBlockMovement(true)
    self.horse:stopAllMovementNow()

    self._lockDir  = self.horse:getDir()
    self.character:setVariable("DismountStarted", true)

    if self.side == "right" then
        if self.saddle then
            self:setActionAnim("Bob_Dismount_Saddle_Right")
        else
            self:setActionAnim("Bob_Dismount_Bareback_Right")
        end
    else
        if self.saddle then
            self:setActionAnim("Bob_Dismount_Saddle_Left")
        else
            self:setActionAnim("Bob_Dismount_Bareback_Left")
        end
    end
end


function DismountHorseAction:stop()
    self.horse:getBehavior():setBlockMovement(false)
    self.character:setVariable("DismountStarted", false)
    ISBaseTimedAction.stop(self)
end


function DismountHorseAction:perform()
    assert(self._lockDir ~= nil)

    self.character:setX(self.landX)
    self.character:setY(self.landY)
    self.character:setZ(self.landZ)

    HorseRiding.removeMount(self.character)

    ISBaseTimedAction.perform(self)
end


---@param mount Mount
---@param side "left" | "right"
---@param saddleItem InventoryItem | nil
---@param landX number
---@param landY number
---@param landZ number
---@return self
---@nodiscard
function DismountHorseAction:new(mount, side, saddleItem, landX, landY, landZ)
    ---@type DismountHorseAction
    local o = ISBaseTimedAction.new(self, mount.pair.rider)
    o.mount = mount
    o.horse = mount.pair.mount
    o.side = side
    o.saddle = saddleItem ~= nil
    o.landX = landX
    o.landY = landY
    o.landZ = landZ
    o.stopOnWalk = true
    o.stopOnRun = true

    o.maxTime = -1
    if o.character:isTimedActionInstant() then
        o.maxTime = 1
    end

    return o
end


return DismountHorseAction