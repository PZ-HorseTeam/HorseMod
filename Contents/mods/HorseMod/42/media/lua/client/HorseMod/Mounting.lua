require("TimedActions/ISPathFindAction")

local HorseRiding = require("HorseMod/Riding")
local MountHorseAction = require("HorseMod/TimedActions/MountHorseAction")
local DismountHorseAction = require("HorseMod/TimedActions/DismountHorseAction")
local MountPair = require("HorseMod/MountPair")
local Attachments = require("HorseMod/attachments/Attachments")
local MountingUtility = require("HorseMod/mounting/MountingUtility")



local Mounting = {}

-- TODO: mountHorse and dismountHorse are too long and have a lot of redundant code



---@param player IsoPlayer
---@param horse IsoAnimal
function Mounting.mountHorse(player, horse)
    if not MountingUtility.canMountHorse(player, horse) then
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
            data:setAttachedTree(nil) ---@diagnostic disable-line
            sendAttachAnimalToTree(horse, player, tree, true)
        end
        -- Detach from any leading player
        local leader = data:getAttachedPlayer()
        if leader then
            leader:getAttachedAnimals():remove(horse)
            data:setAttachedPlayer(nil) ---@diagnostic disable-line
            sendAttachAnimalToPlayer(horse, player, nil, true)  ---@diagnostic disable-line
        end
    end


    --- pathfind to the mount position
    local mountPosition, pathfindAction = MountingUtility.pathfindToHorse(player, horse)

    -- create mount action
    local hasSaddle = Attachments.getSaddle(horse) ~= nil
    local pairing = MountPair.new(player, horse)
    local mountAction = MountHorseAction:new(pairing, mountPosition.name, hasSaddle)

    -- patch to update to last known mount position
    function pathfindAction:perform()
        mountAction.side = self.mountPosition.name
        local PathfindToMountPoint = require("HorseMod/TimedAction/PathfindToMountPoint")
        return PathfindToMountPoint.perform(self)
    end
    
    -- add to queue
    ISTimedActionQueue.add(pathfindAction)
    ISTimedActionQueue.add(mountAction)
end


---@param player IsoPlayer
function Mounting.dismountHorse(player)
    local mount = HorseRiding.getMount(player)
    if not mount then
        return
    end
    local horse = mount.pair.mount

    --- pathfind to the mount position
    local mountPosition, pathfindAction = MountingUtility.pathfindToHorse(player, horse)

    -- dismount
    local hasSaddle = Attachments.getSaddle(horse) ~= nil
    local action = DismountHorseAction:new(
        mount,
        mountPosition,
        hasSaddle
    )

    ISTimedActionQueue.add(action)
end


return Mounting