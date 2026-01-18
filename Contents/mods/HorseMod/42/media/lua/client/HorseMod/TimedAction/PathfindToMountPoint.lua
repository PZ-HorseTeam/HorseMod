---@namespace HorseMod

---REQUIREMENTS
local MountingUtility = require("HorseMod/mounting/MountingUtility")


---@class PathfindToMountPoint : ISWalkToTimedActionF
---@field animal IsoAnimal
---@field mountPosition MountPosition
---@field ticks number
---@field TICKS_BEFORE_PATHFIND number
local PathfindToMountPoint = ISWalkToTimedActionF:derive("PathfindToMountPoint")

function PathfindToMountPoint:waitToStart()
    local animal = self.animal
    if animal:isMoving() or animal:shouldBeTurning() then
        return true
    end

    -- update mount position or cancel pathfind if not reachable
    local mountPosition = MountingUtility.getNearestMountPosition(self.character, animal)
    self.mountPosition = mountPosition
    if not mountPosition then
        self:forceStop()
        return true
    end
    self.location = mountPosition.pos3D ---@diagnostic disable-line
    return ISWalkToTimedActionF.waitToStart(self)
end

function PathfindToMountPoint:update()
    self.animal:getPathFindBehavior2():reset()
    ISWalkToTimedActionF.update(self)
end

---@param character IsoPlayer
---@param mountPosition MountPosition
---@param animal IsoAnimal
---@return self
function PathfindToMountPoint:new(character, mountPosition, animal, ...)
    ---@type PathfindToMountPoint
    local o = ISWalkToTimedActionF.new(
        self,
        character, 
        mountPosition.pos3D,
        ...)

    o.animal = animal
    o.mountPosition = mountPosition

    return o
end


_G[PathfindToMountPoint.Type] = PathfindToMountPoint

return PathfindToMountPoint