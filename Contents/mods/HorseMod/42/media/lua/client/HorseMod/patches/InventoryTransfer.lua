---@namespace HorseMod

---REQUIREMENTS
local Attachments = require("HorseMod/attachments/Attachments")
local AttachmentData = require("HorseMod/attachments/AttachmentData")
local AttachmentsClient = require("HorseMod/attachments/AttachmentsClient")
local HorseManager = require("HorseMod/HorseManager")
local HorseUtils = require("HorseMod/Utils")
local Mounts = require("HorseMod/Mounts")
local AttachmentVisuals = require("HorseMod/attachments/AttachmentVisuals")
local MountingUtility = require("HorseMod/mounting/MountingUtility")
local invTetris = getActivatedMods():contains("\\INVENTORY_TETRIS")

--[[
Patches `ISInventoryTransferAction` to restrict item transfers while mounted on a horse.

When mounted, the player can only transfer items from/to:
- Their own inventory
- Containers they are holding
- Horse attachment containers on the mounted horse that are reachable from mount
- The ground (only as a destination)
- The item is a horse attachment container world item

Also patches `ISGrabItemAction` to prevent grabbing horse attachment containers from the ground. Patches `ISInventoryPaneContextMenu.equipWeapon` to unequip horse attachments when trying to equip as primary or secondary from context menu, instead of equiping the item on the ground itself.

Patches context menus to remove horse attachment containers from the "Extended Placement" menu and hijacks the "Grab" option to unequip the attachment instead of grabbing the item.

Patches the horse context menu when clicking on a horse to hijack the animal grab option to unequip all attachments from the horse when picking it up. This patch goes in pair with `shared/HorseMod/patches/AnimalPickup.lua`. Does the same patch when adding a horse to a vehicle trailer.
]]
local InventoryTransfer = {}

---Find if the given world item is a valid horse attachment container for the given horse and if it can be accessed from mount.
---@param worldItem IsoWorldInventoryObject
---@param horse IsoAnimal
---@return boolean
InventoryTransfer.isValidHorseContainer = function(worldItem, horse)
    -- check if the world item is a horse mod container
    local containerInfo = Attachments.getHorseContainerData(worldItem)
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
    if not srcContainer then
        return true
    end
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
    if not destContainer then
        return true
    end
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
    -- skip if a horse attachment container world item
    local item = self.item
    if item and AttachmentData.containerItems[item:getFullType()] then
        return false
    end

    ---@FIXME patch this for Inventory Tetris compatibility
    -- Allow all transfers if Inventory Tetris is active since it alters transfer action behavior
    if invTetris then
        return InventoryTransfer._originalIsValidTransfer(self)
    end

    -- if the player is mounting a horse, it cannot access certain containers to transfer items from/to
    local horse = Mounts.getMount(self.character)
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

InventoryTransfer._originalIsValidGrab = ISGrabItemAction.isValid
function ISGrabItemAction:isValid()
    -- skip if a horse attachment container world item
    local worldItem = self.item
    local item = worldItem and worldItem:getItem()
    if item and AttachmentData.containerItems[item:getFullType()] then
        return false
    end

    return InventoryTransfer._originalIsValidGrab(self)
end

InventoryTransfer._originalEquipWeapon = ISInventoryPaneContextMenu.equipWeapon
ISInventoryPaneContextMenu.equipWeapon = function(weapon, primary, twoHands, player, alwaysTurnOn)
    repeat
        -- check if this is a horse attachment container
        local worldItem = weapon:getWorldItem()
        if not worldItem then break end

        local containerInfo = Attachments.getHorseContainerData(worldItem)
        if not containerInfo then break end

        local horse = HorseManager.findHorseByID(containerInfo.horseID)
        assert(horse ~= nil, "Tried to unequip a horse attachment container for a horse that doesn't exist or wasn't found (ID: "..tostring(containerInfo.horseID)..").")

        -- since this is a horse container, we hijack the action to instead unequip the attachment
        local playerObj = getSpecificPlayer(player)
        local slot = containerInfo.slot
        local item = AttachmentVisuals.getAttachedItem(horse, slot)
        AttachmentsClient.unequipAccessory(playerObj, horse, slot)

        -- override default parameters then equip the item
        local twoHands = item:isTwoHandWeapon()
        
        ISTimedActionQueue.add(ISEquipWeaponAction:new(playerObj, item, 1, primary, twoHands))
        return
    until true

    -- default behavior
    InventoryTransfer._originalEquipWeapon(weapon, primary, twoHands, player, alwaysTurnOn)
end

---Remove an option from the context menu by its index.
InventoryTransfer.contextMenuRemoveByIndex = function(context, index)
    table.insert(context.optionPool, context.options[index])
    context.options[index] = nil
    context.numOptions = context.numOptions - 1
    if context.requestX ~= nil and context.requestY ~= nil then -- only set for top-level context menus
        context:setSlideGoalX(context.requestX + 20, context.requestX)
        context:setSlideGoalY(context.requestY - context.slideY, context.requestY)
    end
    context:calcHeight()
    context:setWidth(context:calcWidth())
end

---@alias WorldItemOption {item:IsoWorldInventoryObject, index:number, option:umbrella.ISContextMenu.Option, containerInfo:ContainerInformation, player:IsoPlayer}

---Retrieve horse attachment container world items from the given context menu.
---@param context ISContextMenu
---@param playerObj IsoPlayer
---@return WorldItemOption[]
---@nodiscard
InventoryTransfer.getWorldItemsFromMenu = function(context, playerObj)
    local worldItems = {}
    local options = context.options
    for i = 1, #options do repeat
        local option = options[i]

        -- check is a horse attachment container for extended placement menu
        local worldItem = option.target
        if not worldItem or not instanceof(worldItem, "IsoWorldInventoryObject") then
            -- access the world item for grab menu
            local param1 = option.param1
            if type(param1) ~= "table" then break end

            for j = 1, #param1 do
                local obj = param1[j]
                if instanceof(obj, "IsoWorldInventoryObject") then
                    worldItem = obj
                    break
                end
            end
            if not worldItem then break end
        end

        local containerInfo = Attachments.getHorseContainerData(worldItem)
        if not containerInfo then break end

        table.insert(worldItems, {item=worldItem, index=i, option=option, containerInfo=containerInfo, player=playerObj})
    until true end
    return worldItems
end

---Patches the context menu extended placement option to remove horse attachment containers.
---@param context ISContextMenu
---@param playerObj IsoPlayer
InventoryTransfer.patchExtendedPlacement = function(context, playerObj)
    -- find the extended placement option
    local placementOption = context:getOptionFromName(getText("ContextMenu_ExtendedPlacement"))
    if not placementOption then return end

    ---@diagnostic disable-next-line
    local subMenu = context:getSubMenu(placementOption.subOption)
    if not subMenu then return end

    local options = InventoryTransfer.getWorldItemsFromMenu(subMenu, playerObj)

    for i = #options, 1, -1 do repeat
        local option = options[i]
        local index = option.index

        -- remove the option since it's a horse attachment container
        InventoryTransfer.contextMenuRemoveByIndex(subMenu, index)
    until true end

    -- the menu is now empty, so might as well remove the parent option
    if #subMenu.options <= 0 then
        context:removeOptionByName(placementOption.name)
    end
end

---Used to trigger an unequip action when selecting the grab option on a horse attachment container.
---@param worldItemOption WorldItemOption
InventoryTransfer.onSelectGrabWorldItem = function(worldItemOption, ...)
    local containerInfo = worldItemOption.containerInfo

    local horse = HorseManager.findHorseByID(containerInfo.horseID)
    assert(horse ~= nil, "Tried to unequip a horse attachment container for a horse that doesn't exist or wasn't found (ID: "..tostring(containerInfo.horseID)..").")

    -- since this is a horse container, we hijack the action to instead unequip the attachment
    local playerObj = worldItemOption.player
    local slot = containerInfo.slot
    AttachmentsClient.unequipAccessory(playerObj, horse, slot)
end

---Patches the context menu grab option to unequip the attachment instead of grabbing the item.
---@param context ISContextMenu
---@param playerObj IsoPlayer
InventoryTransfer.patchGrab = function(context, playerObj)
    -- find the extended placement option
    local grabOption = context:getOptionFromName(getText("ContextMenu_Grab"))
    if not grabOption then return end

    ---@diagnostic disable-next-line
    local subMenu = context:getSubMenu(grabOption.subOption)
    if not subMenu then return end

    local worldItemOptions = InventoryTransfer.getWorldItemsFromMenu(subMenu, playerObj)

    for i = #worldItemOptions, 1, -1 do repeat
        local worldItemOption = worldItemOptions[i]
        local option = worldItemOption.option

        --- hijack the grab action to instead unequip the attachment
        option.target = worldItemOption
        option.onSelect = InventoryTransfer.onSelectGrabWorldItem
    until true end
end

---Patch the world object context menu to remove the "Extended Placement" of horse attachment containers.
---@param playerNum integer
---@param context ISContextMenu
---@param worldObjects IsoObject[]
---@param test boolean
InventoryTransfer.OnFillWorldObjectContextMenu = function(playerNum, context, worldObjects, test)
    local playerObj = getSpecificPlayer(playerNum)
    InventoryTransfer.patchExtendedPlacement(context, playerObj)
    InventoryTransfer.patchGrab(context, playerObj)
end

Events.OnFillWorldObjectContextMenu.Add(InventoryTransfer.OnFillWorldObjectContextMenu)


---@param horse IsoAnimal
---@param chr IsoPlayer
---@return boolean success True if the actions to remove were valid, or if no gear needed to be removed in the first place
local function removeAttachments(horse, chr)
    --- remove attachments first
    local attachments = Attachments.getAll(horse)
    if #attachments < 1 then
        return true
    end

    local mountPosition = MountingUtility.getNearestMountPosition(chr, horse)
    if mountPosition then
        AttachmentsClient.unequipAllAccessory(chr, horse, attachments, mountPosition)
        return true
    end

    return false
end


InventoryTransfer._originalOnPickupAnimal = AnimalContextMenu.onPickupAnimal
AnimalContextMenu.onPickupAnimal = function(animal, chr)
    if HorseUtils.isHorse(animal) then
        animal:stopAllMovementNow()

        if not removeAttachments(animal, chr) then
            -- this probably won't ever happen, but just in case it does we need some kind of feedback as it cancels the pickup entirely
            chr:Say(getText("ContextMenu_Horse_NoMountPosition"))
            return
        end

        -- reimplement pickup action by stopping the clear of actions from walkAdj
        if luautils.walkAdj(chr, animal:getSquare(), true) then
            ISTimedActionQueue.add(ISPickupAnimal:new(chr, animal))
        end
        return
    end
    
    InventoryTransfer._originalOnPickupAnimal(animal, chr)
end


InventoryTransfer._originalOnAddAnimalTrailer = ISVehicleMenu.onAddAnimalInTrailer
function ISVehicleMenu.onAddAnimalInTrailer(playerObj, animal, vehicle)
    if instanceof(animal, "IsoAnimal") then
        ---@cast animal IsoAnimal
        if HorseUtils.isHorse(animal) then
            removeAttachments(animal, playerObj)
    
            -- call the original action to add the horse to the trailer without the clear of actions from walkAdj
            local vec = vehicle:getAreaCenter("AnimalEntry")
            local sq = getSquare(vec:getX(), vec:getY(), vehicle:getZ())
            if luautils.walkAdj(playerObj, sq, true) then
                ISTimedActionQueue.add(ISAddAnimalInTrailer:new(playerObj, vehicle, animal, false))
            end
            return
        end
    end

    return InventoryTransfer._originalOnAddAnimalTrailer(playerObj, animal, vehicle)
end

return InventoryTransfer