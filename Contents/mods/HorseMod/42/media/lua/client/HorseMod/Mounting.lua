require("TimedActions/ISPathFindAction")

local HorseRiding = require("HorseMod/Riding")
local HorseUtils = require("HorseMod/Utils")
local HorseManager = require("HorseMod/HorseManager")
local MountHorseAction = require("HorseMod/TimedActions/MountHorseAction")
local DismountHorseAction = require("HorseMod/TimedActions/DismountHorseAction")
local MountPair = require("HorseMod/MountPair")


local Mounting = {}


---@type {name: string, attachment: string}[]
local MOUNT_POINTS = table.newarray(
{
        name = "left",
        attachment = "mountLeft"
    },
{
        name = "right",
        attachment = "mountRight"
    }
)


---@param player IsoPlayer
---@param horse IsoAnimal
---@param maxDistance? number Maximum distance the mount position may be from the player to be considered.
---@return {x: number, y: number, name: string} | nil
---@nodiscard
function Mounting.getNearestMountPosition(player, horse, maxDistance)
    local nearestDistanceSquared    
    if not maxDistance then
        nearestDistanceSquared = math.huge 
    else
        nearestDistanceSquared = maxDistance^2
    end

    ---@type {x: number, y: number, name: string} | nil
    local nearest = nil

    for i = 1, #MOUNT_POINTS do
        local mountPoint = MOUNT_POINTS[i]
        local attachmentPosition = horse:getAttachmentWorldPos(mountPoint.attachment)
        local x = attachmentPosition:x()
        local y = attachmentPosition:y()
        local distanceSquared = player:DistToSquared(x, y)
        if distanceSquared <= nearestDistanceSquared then
            nearest = {
                x = x,
                y = y,
                name = mountPoint.name
            }
            nearestDistanceSquared = distanceSquared
        end
    end

    if not nearest then
        return nil
    end

    return nearest
end


---@param player IsoPlayer
---@param radius number | nil
---@return IsoAnimal | nil
---@nodiscard
function Mounting.getBestMountableHorse(player, radius)
    radius = radius or 1.25

    local bestHorse = nil
    local bestDistanceSquared = radius^2

    for i = 1, #HorseManager.horses do
        local horse = HorseManager.horses[i]
        local mountPos = Mounting.getNearestMountPosition(player, horse, radius)
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


-- TODO: mountHorse and dismountHorse are too long and have a lot of redundant code


---@param player IsoPlayer
---@param horse IsoAnimal
function Mounting.mountHorse(player, horse)
    if not HorseRiding.canMountHorse(player, horse) then
        return
    end

    local data = horse:getData()
    -- TODO: check if this nil check is actually necessary
    --  an animal's data *is* null by default,
    --  but it seems like it might always gets initialised when the animal spawns
    if data then
        -- Detach from tree
        local tree = data:getAttachedTree()
        if tree then
            sendAttachAnimalToTree(horse, player, tree, true)
            data:setAttachedTree(nil)
        end
        -- Detach from any leading player
        local leader = data:getAttachedPlayer()
        if leader then
            leader:getAttachedAnimals():remove(horse)
            data:setAttachedPlayer(nil)
        end
    end

    -- Ensure the mounting player isn't leading the horse
    player:removeAttachedAnimal(horse)

    -- Freeze horse and remember direction
    horse:getPathFindBehavior2():reset()

    local behavior = horse:getBehavior()
    behavior:setBlockMovement(true)
    behavior:setDoingBehavior(false)

    horse:stopAllMovementNow()
    local lockDir = horse:getDir()

    -- Keep horse direction locked while walking to
    local function lockTick()
        if horse:isExistInTheWorld() then
            horse:setDir(lockDir)
        end
    end
    Events.OnTick.Add(lockTick)

    local mountPosition = Mounting.getNearestMountPosition(player, horse)
    assert(mountPosition ~= nil)

    local path = ISPathFindAction:pathToLocationF(
        player,
        mountPosition.x,
        mountPosition.y,
        horse:getZ()
    )

    local function cleanup()
        Events.OnTick.Remove(lockTick)
        horse:getBehavior():setBlockMovement(false)
    end

    path.stop = function(self)
        cleanup()
        ISPathFindAction.stop(self)
    end

    path.perform = function(self)
        cleanup()
        ISPathFindAction.perform(self)
    end


    ISTimedActionQueue.add(path)

    local saddle = HorseUtils.getSaddle(horse)
    local pairing = MountPair.new(player, horse)

    ISTimedActionQueue.add(
        MountHorseAction:new(pairing, mountPosition.name, saddle)
    )
end


---@param player IsoPlayer
function Mounting.dismountHorse(player)
    local mount = HorseRiding.getMount(player)
    if not mount then
        return
    end

    local horse = mount.pair.mount

    horse:getPathFindBehavior2():reset()

    local behavior = horse:getBehavior()
    behavior:setBlockMovement(true)
    behavior:setDoingBehavior(false)

    horse:stopAllMovementNow()
    local lockDir = horse:getDir()

    local lpos = horse:getAttachmentWorldPos("mountLeft")
    local rpos = horse:getAttachmentWorldPos("mountRight")
    local hx, hy = horse:getX(), horse:getY()

    local dl = (hx - lpos:x())^2 + (hy - lpos:y())^2
    local dr = (hx - rpos:x())^2 + (hy - rpos:y())^2
    local side, tx, ty, tz = "right", rpos:x(), rpos:y(), rpos:z()
    if dl < dr then side, tx, ty, tz = "left", lpos:x(), lpos:y(), lpos:z() end

    local function centerBlocked(nx, ny, nz)
        local sq = getSquare(nx, ny, nz)
        if not sq then
            return true
        end
        if sq:isSolid() or sq:isSolidTrans() then
            return true
        end
        return false
    end

    if centerBlocked(tx, ty, tz) then
        local ox = (side=="right") and lpos:x() or rpos:x()
        local oy = (side=="right") and lpos:y() or rpos:y()
        local oz = (side=="right") and lpos:z() or rpos:z()
        if not centerBlocked(ox, oy, oz) then
            if side == "right" then
                side = "left"
            else
                side = "right"
            end
            tx, ty, tz = ox, oy, oz
        end
    end

    local saddleItem = HorseUtils.getSaddle(horse)

    player:setDir(lockDir)

    local action = DismountHorseAction:new(
        mount,
        side,
        saddleItem ~= nil,
        tx,
        ty,
        tz
    )

    ISTimedActionQueue.add(action)
end


return Mounting