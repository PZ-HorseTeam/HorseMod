---@namespace HorseMod

---REQUIREMENTS
local HorseManager = require("HorseMod/HorseManager")
local Mounts = require("HorseMod/Mounts")
local HorseUtils = require("HorseMod/Utils")


local MOUNTING_DISABLED = isClient() and not isDebugEnabled()


local MountingUtility = {}


---@TODO should probably use the Attachments system to get mount points ?
---Holds the different mounting points on a horse.
---@type {name: string, attachment: string}[]
local MOUNT_POINTS = table.newarray(
{
        name = "Left",
        attachment = "mountLeft"
    },
{
        name = "Right",
        attachment = "mountRight"
    }
)

---@alias MountPosition {x: number, y: number, name: string, pos3D: Position3D, attachment: string}


---Retrieve the nearest mount position on the given horse to the player.
---@param player IsoPlayer
---@param horse IsoAnimal
---@param maxDistance? number Maximum distance the mount position may be from the player to be considered.
---@return MountPosition | nil
---@nodiscard
function MountingUtility.getNearestMountPosition(player, horse, maxDistance)
    local nearestDistanceSquared    
    if not maxDistance then
        nearestDistanceSquared = math.huge 
    else
        nearestDistanceSquared = maxDistance^2
    end

    local horse_square = horse:getSquare()

    ---@type MountPosition | nil
    local nearest = nil

    for i = 1, #MOUNT_POINTS do repeat
        local mountPoint = MOUNT_POINTS[i]
        local attachment = mountPoint.attachment
        local attachmentPosition = horse:getAttachmentWorldPos(attachment)
        if not attachmentPosition then break end
        
        local x = attachmentPosition:x()
        local y = attachmentPosition:y()
        local distanceSquared = player:DistToSquared(x, y)
        if distanceSquared <= nearestDistanceSquared then
            local square = getSquare(x, y, horse_square:getZ())
            if square and not horse_square:isBlockedTo(square) then
                ---@type MountPosition
                nearest = {
                    x = x,
                    y = y,
                    name = mountPoint.name,
                    pos3D = attachmentPosition,
                    attachment = attachment,
                }
                nearestDistanceSquared = distanceSquared
            end
        end
    until true end

    return nearest
end


---@param player IsoPlayer
---@param radius number | nil
---@return IsoAnimal | nil
---@nodiscard
function MountingUtility.getBestMountableHorse(player, radius)
    radius = radius or 1.25

    local bestHorse = nil
    local bestDistanceSquared = radius^2

    for i = 1, #HorseManager.horses do
        local horse = HorseManager.horses[i]
        local mountPos = MountingUtility.getNearestMountPosition(player, horse, radius)
        if mountPos then
            local distanceSquared = player:DistToSquared(mountPos.x, mountPos.y)
            if distanceSquared <= bestDistanceSquared then
                bestHorse = horse
                bestDistanceSquared = distanceSquared
            end
        end
    end

    return bestHorse
end


---Verify that the player can mount a horse.
---@param player IsoPlayer
---@param horse IsoAnimal
---@return boolean
---@return string?
---@nodiscard
function MountingUtility.canMountHorse(player, horse)
    if MOUNTING_DISABLED then
        return false, "IGUI_HorseMod_DisabledInMultiplayer"
    elseif Mounts.hasMount(player) then
        -- already mounted
        return false
    elseif Mounts.hasRider(horse) then
        return false, "ContextMenu_Horse_IsAlreadyRiding"
    elseif horse:isDead() then
        return false, "ContextMenu_Horse_IsDead"
    elseif horse:isOnHook() then -- butcher hook
        return false
    elseif horse:getVariableBoolean("animalRunning") and horse:getMovementSpeed() ~= 0 then
        return false, "ContextMenu_Horse_IsRunning"
    elseif not HorseUtils.isAdult(horse) then
        return false, "ContextMenu_Horse_NotAdult"
    end

    ---@TODO is this needed anymore ? I wasn't able to properly test it because
    ---even if I comment this I can't mount the horse, and I didn't find the exact reason why
    local state = horse:getCurrentStateName()
    if state == "AnimalFollowWallState" then
        return false
    end

    return true
end



---Make the player pathfind to the nearest mount point on the horse. First stops the horse from moving and then move to the horse nearest mounting position.
---@param player IsoPlayer
---@param horse IsoAnimal
---@param mountPosition MountPosition
---@return PathfindToMountPoint
function MountingUtility.pathfindToHorse(player, horse, mountPosition)
    --- pathfind to the mount position
    local PathfindToMountPoint = require("HorseMod/TimedAction/PathfindToMountPoint")
    local pathfindAction = PathfindToMountPoint:new(
        player,
        mountPosition,
        horse
    )

    -- stop the horse from moving
    horse:getPathFindBehavior2():reset()

    ISTimedActionQueue.add(pathfindAction)

    return pathfindAction
end


return MountingUtility