---@namespace HorseMod

---REQUIREMENTS
local HorseUtils = require("HorseMod/Utils")
local HorseManager = require("HorseMod/HorseManager")

---@class ContainerInformation
---@field x number
---@field y number
---@field z number
---@field fullType string
---@field itemID number
---@field worldItem IsoWorldInventoryObject?
---@field horseID number
---@field slot AttachmentSlot

---Holds all the utility functions to manage containers on horses.
local ContainerManager = {
    ---Containers that were found as horse containers
    ---@type table<number, IsoWorldInventoryObject>
    ORPHAN_CONTAINERS = {},
}
local ORPHAN_CONTAINERS = ContainerManager.ORPHAN_CONTAINERS

local function refreshInventories(player)
    local pdata = getPlayerData(player:getPlayerNum())
    ---@diagnostic disable-next-line
    pdata.playerInventory:refreshBackpacks()
    ---@diagnostic disable-next-line
    pdata.lootInventory:refreshBackpacks()
    triggerEvent("OnContainerUpdate")
end

---Transfert every items from the `srcContainer` to the `destContainer`.
---@param player IsoPlayer
---@param srcContainer ItemContainer
---@param destContainer ItemContainer
ContainerManager.transferAll = function(player, srcContainer, destContainer)
    local items = srcContainer:getItems()
    if not items then return end
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        ISTransferAction:transferItem(player, item, srcContainer, destContainer, nil)    
    end
end

---@param horse IsoAnimal
---@param slot AttachmentSlot
---@param worldItem IsoWorldInventoryObject?
ContainerManager.registerContainerInformation = function(horse, slot, worldItem)
    local modData = HorseUtils.getModData(horse)
    local containers = modData.containers

    -- remove info
    if not worldItem then
        -- clear cached and saved info        
        containers[slot] = nil
    else
        local item = worldItem:getItem()

        -- init container info table
        ---@type ContainerInformation
        local containerInfo = {
            -- world item position
            worldItem = worldItem,
            x = worldItem:getX(),
            y = worldItem:getY(),
            z = worldItem:getZ(),

            -- identification informations
            fullType = item:getFullType(),
            itemID = item:getID(),
            horseID = horse:getAnimalID(),
            slot = slot,
        }

        -- mark the world item as a horse mod container to more easily find later
        ContainerManager.setContainerData(worldItem, containerInfo)

        -- store in mod data
        containers[slot] = containerInfo
    end
end

---@param worldItem IsoWorldInventoryObject
---@param containerInfo ContainerInformation
ContainerManager.setContainerData = function(worldItem, containerInfo)
    -- update container world item informations
    containerInfo.worldItem = worldItem
    containerInfo.x = worldItem:getX()
    containerInfo.y = worldItem:getY()
    containerInfo.z = worldItem:getZ()

    -- save in mod data
    local md = worldItem:getItem():getModData()
    md.HorseMod = md.HorseMod or {}
    md.HorseMod.container = containerInfo
end

---@param worldItem IsoWorldInventoryObject
---@return ContainerInformation?
ContainerManager.getHorseContainerData = function(worldItem)
    local md_horse = worldItem:getItem():getModData().HorseMod
    local container = md_horse and md_horse.container
    if container then
        return container
    end
    return nil
end

---@param player IsoPlayer
---@param horse IsoAnimal
---@param slot AttachmentSlot
---@param containerBehavior ContainerBehavior
---@param accessory InventoryContainer
ContainerManager.initContainer = function(player, horse, slot, containerBehavior, accessory)
    -- retrieve the container of the accessory
    local srcContainer = accessory:getItemContainer()
    assert(srcContainer ~= nil, "Accessory has container behavior but isn't a container.")

    -- retrieve the square the horse is on
    local square = horse:getSquare()
    assert(square ~= nil, "Horse isn't on a square.")

    -- create the invisible container
    local containerItem = square:AddWorldInventoryItem(containerBehavior.worldItem, 0,0,0)
    assert(containerItem:IsInventoryContainer(), "Invisible container ("..containerBehavior.worldItem..") used for "..accessory:getFullType().." isn't a container.")
    ---@cast containerItem InventoryContainer

    containerItem:setName(accessory:getDisplayName())
    containerItem:setIcon(accessory:getIcon())
    local worldItem = containerItem:getWorldItem()
    local destContainer = containerItem:getItemContainer()

    -- transfer everything to the invisible container
    ContainerManager.transferAll(player, srcContainer, destContainer)
    refreshInventories(player)

    -- register in the data of the horse the container being attached
    ContainerManager.registerContainerInformation(horse, slot, worldItem)
end

---@param player IsoPlayer
---@param horse IsoAnimal
---@param slot AttachmentSlot
---@param accessory InventoryContainer
ContainerManager.removeContainer = function(player, horse, slot, accessory)
    -- retrieve the world container
    local worldItem = ContainerManager.getContainer(horse, slot)
    assert(worldItem ~= nil, "worldItem container not found.")
    
    -- retrieve the inventory container
    local container = accessory:getItemContainer()
    assert(container ~= nil, "Accessory doesn't have an ItemContainer. ("..tostring(accessory)..")")

    -- retrieve the InventoryItem of worldItem
    local containerItem = worldItem:getItem() --[[@as InventoryContainer]]
    assert(containerItem:IsInventoryContainer(), "worldItem isn't an InventoryContainer. ("..tostring(containerItem)..")")

    -- transfer items from world to inventory container
    ContainerManager.transferAll(player, containerItem:getItemContainer(), container)
    
    -- delete world item
    local square = horse:getSquare()
    assert(square ~= nil, "Horse isn't on a square.")

    square:transmitRemoveItemFromSquare(worldItem)
    worldItem:removeFromWorld()
    worldItem:removeFromSquare()
    ---@diagnostic disable-next-line
    worldItem:setSquare(nil)

    refreshInventories(player)

    -- sync cached and saved informations
    ContainerManager.registerContainerInformation(horse, slot, nil)
end

---@param worldItem IsoWorldInventoryObject
---@return boolean
ContainerManager.isContainer = function(worldItem)
    local md = worldItem:getItem():getModData().HorseMod
    if md then
        if md.container then
            return true
        end
    end
    return false
end

---@param worldItem IsoWorldInventoryObject
---@param containerInfo ContainerInformation
---@return boolean
---@return number?
ContainerManager.isSearchedContainer = function(worldItem, containerInfo)
    local itemID = worldItem:getItem():getID()
    if containerInfo.itemID == itemID then
        return true
    end
    return false, itemID
end

---@param square IsoGridSquare
---@param itemIDSearched number
---@return IsoWorldInventoryObject?
ContainerManager.findContainerOnSquare = function(square, itemIDSearched)
    local worldItems = square:getWorldObjects()
    for i = 0, worldItems:size() - 1 do
        local worldItem = worldItems:get(i)
        
        -- check if the world item corresponds to an attachment container
        if ContainerManager.isContainer(worldItem) then
            local itemID = worldItem:getItem():getID()

            -- verify it has the right ID
            if itemIDSearched == itemID then
                return worldItem
            else
                ORPHAN_CONTAINERS[itemID] = worldItem
            end
        end
    end
    return nil
end

---Find the horse container by different means.
---@param horse IsoAnimal
---@param containerInfo ContainerInformation
---@param squareHorse IsoGridSquare
---@return IsoWorldInventoryObject?
ContainerManager.findContainer = function(horse, containerInfo, squareHorse)
    local itemIDSearched = containerInfo.itemID

    -- check orphaned containers
    local worldItem = ORPHAN_CONTAINERS[itemIDSearched]
    if worldItem then
        -- verify that this is still the same item reference
        local itemID = worldItem:getItem():getID()
        if itemID == itemIDSearched then
            ContainerManager.setContainerData(worldItem, containerInfo)
            return worldItem
        end

        -- this is no longer be a valid container ref or outdated one
        if ContainerManager.isContainer(worldItem) then
            local itemID = worldItem:getItem():getID()
            ORPHAN_CONTAINERS[itemID] = worldItem -- update ref
        else
            ORPHAN_CONTAINERS[itemID] = nil -- remove ref
        end
    end


    -- local x, y, z = horse:getX(), horse:getY(), horse:getZ()
    -- local sq = getSquare(x, y, z)

    -- check the last known coordinates of the container
    local sq = getSquare(containerInfo.x, containerInfo.y, containerInfo.z)
    if sq then
        local worldItem = ContainerManager.findContainerOnSquare(sq, itemIDSearched)
        if worldItem then
            ContainerManager.setContainerData(worldItem, containerInfo)
            return worldItem 
        end
    end

    -- check if the world items on the horse square are the container
    ---@FIXME this method can also catch other horses worldItems. This shouldn't be a
    ---problem, since we verify their indentify before using them
    ---and their identity can't link to 2 different horses
    if squareHorse then
        local worldItem = ContainerManager.findContainerOnSquare(squareHorse, itemIDSearched)
        if worldItem then
            ContainerManager.setContainerData(worldItem, containerInfo)
            return worldItem 
        end
    end

    return nil
end

---@param horse IsoAnimal
---@param slot AttachmentSlot
---@return IsoWorldInventoryObject?
ContainerManager.getContainer = function(horse, slot)
    --  verify horse should have a container there
    local modData = HorseUtils.getModData(horse)
    local containers = modData.containers
    local containerInfo = containers[slot]
    if not containerInfo then return end

    -- if container not cached, find it
    local worldItem = containerInfo.worldItem
    if not worldItem then
        worldItem = ContainerManager.findContainer(horse, containerInfo, horse:getSquare())

        -- cache container or nil
        containerInfo.worldItem = worldItem
    end

    return worldItem
end

---Change the position of the worldItem.
---@param squareHorse IsoGridSquare
---@param containerInfo ContainerInformation
---@param worldItem IsoWorldInventoryObject
---@param horse IsoAnimal
ContainerManager.moveWorldItem = function(squareHorse, containerInfo, worldItem, horse)
    -- remove the item from its square
    local item = worldItem:getItem()
    worldItem:removeFromSquare()
    worldItem:removeFromWorld()

    -- move it to the new square
    local worldItem = squareHorse:AddWorldInventoryItem(item, 0, 0, 0):getWorldItem()

    -- mark the world item as a horse mod container to more easily find later
    ContainerManager.setContainerData(worldItem, containerInfo)
end

---Track and update the position of the horse attachment containers.
---@param horse IsoAnimal
ContainerManager.track = function(horse)
    local squareHorse = horse:getSquare()
    if not squareHorse then return end -- horse is flying ?

    -- get containers linked to the horse
    local modData = HorseUtils.getModData(horse)
    local containers = modData.containers

    -- for each container, retrieve its worldItem and move it if needed
    for slot, containerInfo in pairs(containers) do repeat
        -- if world item ref is cached, then handle move
        local worldItem = containerInfo.worldItem
        if worldItem then
            -- update its position if the square is different
            local square = worldItem:getRenderSquare()
            if square and square ~= squareHorse then
                ContainerManager.moveWorldItem(squareHorse, containerInfo, worldItem, horse)
            end

        -- search for the container world item
        else
            local worldItemNew = ContainerManager.findContainer(horse, containerInfo, squareHorse)
            if worldItemNew then
                ContainerManager.moveWorldItem(squareHorse, containerInfo, worldItemNew, horse)
            end
        end
    until true end
end

-- consider horse loses all world item refs
HorseManager.onHorseRemoved:add(function(horse)
    -- get containers linked to the horse
    local modData = HorseUtils.getModData(horse)
    local containers = modData.containers

    -- for each container, retrieve its worldItem and reset its world item ref
    for slot, containerInfo in pairs(containers) do
        containerInfo.worldItem = nil
    end
end)

return ContainerManager
