require("TimedActions/ISBaseTimedAction")

local AnimationVariables = require("HorseMod/AnimationVariables")


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
---@field hasSaddle boolean
---
---@field landX number
---
---@field landY number
---
---@field landZ number
local DismountHorseAction = ISBaseTimedAction:derive("HorseMod_DismountHorseAction")


---@return boolean
function DismountHorseAction:isValid()
    return self.horse:isExistInTheWorld()
           and self.character:getAttachedAnimals():contains(self.horse) or false
end


function DismountHorseAction:update()
    assert(self._lockDir ~= nil)

    -- keep the horse locked facing the stored direction
    self.horse:setDir(self._lockDir)

    if self.character:getVariableBoolean(AnimationVariables.DISMOUNT_FINISHED) == true then
        self.character:setVariable(AnimationVariables.DISMOUNT_FINISHED, false)
        self:forceComplete()
    end
end


function DismountHorseAction:start()
    self.horse:getPathFindBehavior2():reset()
    self.horse:getBehavior():setBlockMovement(true)
    self.horse:stopAllMovementNow()

    self._lockDir  = self.horse:getDir()
    self.character:setVariable(AnimationVariables.DISMOUNT_STARTED, true)

    if self.side == "right" then
        if self.hasSaddle then
            self:setActionAnim("Bob_Dismount_Saddle_Right")
        else
            self:setActionAnim("Bob_Dismount_Bareback_Right")
        end
    else
        if self.hasSaddle then
            self:setActionAnim("Bob_Dismount_Saddle_Left")
        else
            self:setActionAnim("Bob_Dismount_Bareback_Left")
        end
    end
end


function DismountHorseAction:stop()
    self.horse:getBehavior():setBlockMovement(false)
    self.character:setVariable(AnimationVariables.DISMOUNT_STARTED, false)
    ISBaseTimedAction.stop(self)
end


function DismountHorseAction:complete()
    require("HorseMod/Riding").removeMount(self.character)
    require("HorseMod/Mounts").removeMount(self.character)
    return true
end


function DismountHorseAction:perform()
    assert(self._lockDir ~= nil)

    self.character:setX(self.landX)
    self.character:setY(self.landY)
    self.character:setZ(self.landZ)

    ISBaseTimedAction.perform(self)
end


function DismountHorseAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end

    return -1
end


---@param mount Mount
---@param side "left" | "right"
---@param hasSaddle boolean
---@param landX number
---@param landY number
---@param landZ number
---@return self
---@nodiscard
function DismountHorseAction:new(mount, side, hasSaddle, landX, landY, landZ)
    ---@type DismountHorseAction
    local o = ISBaseTimedAction.new(self, mount.pair.rider)

    -- HACK: this loses its metatable when transmitted by the server
    setmetatable(mount, require("HorseMod/mount/Mount"))
    o.mount = mount
    o.horse = mount.pair.mount
    o.side = side
    o.hasSaddle = hasSaddle
    o.landX = landX
    o.landY = landY
    o.landZ = landZ
    o.stopOnWalk = true
    o.stopOnRun = true

    o.maxTime = o:getDuration()

    return o
end


_G[DismountHorseAction.Type] = DismountHorseAction


return DismountHorseAction