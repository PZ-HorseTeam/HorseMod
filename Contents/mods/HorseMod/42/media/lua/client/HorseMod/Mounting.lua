---@namespace HorseMod

---REQUIREMENTS
local MountAction = require("HorseMod/TimedActions/MountAction")
local DismountAction = require("HorseMod/TimedActions/DismountAction")
local UrgentDismountAction = require("HorseMod/TimedActions/UrgentDismountAction")
local Attachments = require("HorseMod/attachments/Attachments")
local MountingUtility = require("HorseMod/mounting/MountingUtility")
local AnimationVariable = require('HorseMod/definitions/AnimationVariable')
local HorseSounds = require("HorseMod/HorseSounds")



local Mounting = {}
-- local mountPosition = MountingUtility.getNearestMountPosition(player, horse)

---@param player IsoPlayer
---@param horse IsoAnimal
---@param mountPosition MountPosition
function Mounting.mountHorse(player, horse, mountPosition)
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
    local pathfindAction = MountingUtility.pathfindToHorse(player, horse, mountPosition)

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
---@param mountPosition MountPosition
function Mounting.dismountHorse(player, horse, mountPosition)
    --- pathfind to the mount position
    MountingUtility.pathfindToHorse(player, horse, mountPosition)

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

---@param player IsoPlayer
---@return boolean
function Mounting.canDismountUrgent(player)
    -- prevent multiple urgent dismount actions
    local queue = ISTimedActionQueue.getTimedActionQueue(player)
    local actionIndex = queue:indexOfType(UrgentDismountAction.Type)
    if actionIndex >= 0 then
        return false
    end
    return true
end

---@param player IsoPlayer
---@param horse IsoAnimal
function Mounting.dismountDeath(player, horse)
    if not Mounting.canDismountUrgent(player) then return end

    ISTimedActionQueue.add(UrgentDismountAction:new(
        player,
        horse,
        AnimationVariable.DYING,
        nil,
        "PainFromFallLow",
        true
    ))
end

---@param player IsoPlayer
---@param horse IsoAnimal
function Mounting.dismountFall(player, horse)
    if not Mounting.canDismountUrgent(player) then return end

    ISTimedActionQueue.add(UrgentDismountAction:new(
        player,
        horse,
        nil,
        HorseSounds.Sound.STRESSED,
        nil,
        true
    ))
end

---@param player IsoPlayer
---@param horse IsoAnimal
function Mounting.dismountFallBack(player, horse)
    if not Mounting.canDismountUrgent(player) then return end

    ISTimedActionQueue.add(UrgentDismountAction:new(
        player,
        horse,
        AnimationVariable.FALL_BACK,
        HorseSounds.Sound.PAIN,
        "PainFromFallHigh",
        true
    ))
end

return Mounting