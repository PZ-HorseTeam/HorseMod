local MountAction = require("HorseMod/TimedActions/MountAction")
local DismountAction = require("HorseMod/TimedActions/DismountAction")
local Attachments = require("HorseMod/attachments/Attachments")
local MountingUtility = require("HorseMod/mounting/MountingUtility")



local Mounting = {}


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
    local mountAction = MountAction:new(
        player,
        horse,
        mountPosition,
        hasSaddle
    )

    ---@FIXME spaghetti shit right there, needs a better way of handling this
    -- patch to update to last known mount position
    function pathfindAction:perform()
        mountAction.mountPosition = self.mountPosition
        local PathfindToMountPoint = require("HorseMod/TimedAction/PathfindToMountPoint")
        return PathfindToMountPoint.perform(self)
    end

    ISTimedActionQueue.add(mountAction)
end

---@param horse IsoAnimal
---@param player IsoPlayer
function Mounting.dismountHorse(player, horse)
    --- pathfind to the mount position
    local mountPosition, pathfindAction = MountingUtility.pathfindToHorse(player, horse)

    -- dismount
    local hasSaddle = Attachments.getSaddle(horse) ~= nil
    local action = DismountAction:new(
        player,
        horse,
        mountPosition,
        hasSaddle
    )

    ISTimedActionQueue.add(action)
end


return Mounting