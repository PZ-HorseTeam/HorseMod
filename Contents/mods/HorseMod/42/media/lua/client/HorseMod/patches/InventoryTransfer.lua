---REQUIREMENTS
local HorseRiding = require("HorseMod/Riding")
local Attachments = require("HorseMod/attachments/Attachments")
local ContainerManager = require("HorseMod/attachments/ContainerManager")
local invTetris = getActivatedMods():contains("\\INVENTORY_TETRIS")

--[[
Patches `ISInventoryTransferAction` to restrict item transfers while mounted on a horse.

When mounted, the player can only transfer items from/to:
- Their own inventory
- Containers they are holding
- Horse attachment containers on the mounted horse that are reachable from mount
- The ground (only as a destination)
]]
local InventoryTransfer = {}

---Find if the given world item is a valid horse attachment container for the given horse and if it can be accessed from mount.
---@param worldItem IsoWorldInventoryObject
---@param horse IsoAnimal
---@return boolean
InventoryTransfer.isValidHorseContainer = function(worldItem, horse)
    -- check if the world item is a horse mod container
    local containerInfo = ContainerManager.getHorseContainerData(worldItem)
    if not containerInfo then return false end
    
    -- check if the container is from the horse
    if containerInfo.horseID ~= horse:getAnimalID() then return false end

    -- check if it can't be accessed by the player from mount
    local slot = containerInfo.slot
    local fullType = containerInfo.fullType
    local attachmentDef = Attachments.getAttachmentDefinition(fullType, slot)
    if attachmentDef and attachmentDef.notReachableFromMount then
        return false
    end

    return true
end

---Verify if a source container is valid for transfer while mounted on a horse. The source must be the player inventory, a container the player is holding or a horse attachment container on the mounted horse which can be accessed from mount.
---@param srcContainer ItemContainer
---@param character IsoPlayer
---@param horse IsoAnimal
---@return boolean
InventoryTransfer.isValidSource = function(srcContainer, character, horse)
    -- if source container is the player inventory allow
    local parent = srcContainer:getParent()
    if parent and parent == character then
        return true
    end

    -- access the InventoryItem item, if nil it's the ground itself
    local containerItem = srcContainer:getContainingItem()
    if not containerItem then return false end

    -- access the world item
    local worldItem = containerItem:getWorldItem()
    if not worldItem then
        -- verify if the item is in the player inventory
        local playerInventory = character:getInventory()
        if playerInventory:containsRecursive(containerItem) then
            return true
        end

        return false
    end

    if not InventoryTransfer.isValidHorseContainer(worldItem, horse) then
        return false
    end

    return true
end

---Verify if a destination container is valid for transfer while mounted on a horse. The destination must be rechable from mount, so either in the player inventory, a container the player is holding or a horse attachment container on the mounted horse which can be accessed from mount. It can also be the ground but it cannot be a container on the ground since the player can't reach it from mount.
---@param destContainer ItemContainer
---@param character IsoPlayer
---@param horse IsoAnimal
---@return boolean
InventoryTransfer.isValidDestination = function(destContainer, character, horse)
    -- if source container is the player inventory allow
    local parent = destContainer:getParent()
    if parent and parent == character then
        return true
    end

    -- access the InventoryItem item, if nil it's the ground itself
    local containerItem = destContainer:getContainingItem()
    if not containerItem then return true end

    -- access the world item, if no world item, it's on the ground
    local worldItem = containerItem:getWorldItem()
    if not worldItem then return true end

    if InventoryTransfer.isValidHorseContainer(worldItem, horse) then
        return true
    end

    return false
end


InventoryTransfer._originalIsValidTransfer = ISInventoryTransferAction.isValid
function ISInventoryTransferAction:isValid()
    ---@FIXME patch this for Inventory Tetris compatibility
    -- Allow all transfers if Inventory Tetris is active since it alters transfer action behavior
    if invTetris then
        return InventoryTransfer._originalIsValidTransfer(self)
    end

    -- if the player is mounting a horse, it cannot access certain containers to transfer items from/to
    local horse = HorseRiding.getMountedHorse(self.character)
    if horse then
        local srcContainer = self.srcContainer
        local destContainer = self.destContainer
        local character = self.character

        -- verify source and destination containers are valid while mounted
        local checkSrc = InventoryTransfer.isValidSource(srcContainer, character, horse)
        local checkDest = InventoryTransfer.isValidDestination(destContainer, character, horse)
        if not checkSrc or not checkDest then
            return false
        end
    end

    return InventoryTransfer._originalIsValidTransfer(self)
end

return InventoryTransfer