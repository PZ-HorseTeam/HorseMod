---@namespace HorseMod

---REQUIREMENTS
local HorseUtils = require("HorseMod/Utils")
local Attachments = require("HorseMod/attachments/Attachments")
local ISHorseEquipGear = require("HorseMod/TimedActions/ISHorseEquipGear")
local ISHorseUnequipGear = require("HorseMod/TimedActions/ISHorseUnequipGear")

local AttachmentsManager = {}


---Equip a new accessory on the horse.
---@param player IsoPlayer
---@param horse IsoAnimal
---@param accessory InventoryItem
AttachmentsManager.equipAccessory = function(context, player, horse, accessory)
    if context then
        context:closeAll()
    end
    local unlock, side = HorseUtils.pathfindToHorse(player, horse)
    
    -- verify an attachment isn't already equiped, else unequip it
    local attachmentDef = Attachments.getAttachmentDefinition(accessory:getFullType())
    local slot = attachmentDef.slot
    local oldAccessory = Attachments.getAttachedItem(horse, slot)
    if oldAccessory then
        ISTimedActionQueue.add(ISHorseUnequipGear:new(player, horse, oldAccessory, nil, unlock))
    end
    
    -- equip the attachment in hands
    local equipItemAction = ISEquipWeaponAction:new(player, accessory, 50, true, accessory:isTwoHandWeapon())
    equipItemAction.stopOnWalk = true
    equipItemAction.stopOnAim = true
    ISTimedActionQueue.add(equipItemAction)

    -- equip the attachment on horse
    ISTimedActionQueue.add(ISHorseEquipGear:new(player, horse, accessory, side, unlock))
end

---Unequip a specific accessory on the horse.
---@param player IsoPlayer
---@param horse IsoAnimal
---@param oldAccessory InventoryItem
AttachmentsManager.unequipAccessory = function(context, player, horse, oldAccessory)
    if context then
        context:closeAll()
    end
    local unlock, side = HorseUtils.pathfindToHorse(player, horse)
    ISTimedActionQueue.add(ISHorseUnequipGear:new(player, horse, oldAccessory, side, unlock))
end

---Unequip every accessories on the horse.
---@param player IsoPlayer
---@param horse IsoAnimal
---@param oldAccessories InventoryItem[]
AttachmentsManager.unequipAllAccessory = function(context, player, horse, oldAccessories)
    if context then
        context:closeAll()
    end
    local unlock, side = HorseUtils.pathfindToHorse(player, horse)
    
    -- unequip all
    local accessoryCount = #oldAccessories
    for i = 1, accessoryCount do
        local oldAccessory = oldAccessories[i] --[[@as InventoryItem]]
        local shouldUnlockOnPerform = i == accessoryCount and unlock or nil
        ISTimedActionQueue.add(ISHorseUnequipGear:new(player, horse, oldAccessory, side, shouldUnlockOnPerform, unlock))
    end
end


---Add the equip and unequip context menu options for horse gear.
---@param player IsoPlayer
---@param horse IsoAnimal
---@param context ISContextMenu
---@param accessories ArrayList
---@param horseOption umbrella.ISContextMenu.Option
AttachmentsManager.populateHorseContextMenu = function(player, horse, context, accessories, horseOption)
    -- retrieve horse context menu
    ---@diagnostic disable-next-line
    local horseSubMenu = context:getSubMenu(horseOption.subOption) --[[@as ISContextMenu]]

    -- create gear submenu, even if no gear is available
    local gearOption = horseSubMenu:addOption(getText("ContextMenu_Horse_Gear"))
    if horse:getVariableBoolean("animalRunning") then
        -- can't equip gear on a running horse
        gearOption.notAvailable = true
        local tooltip = ISWorldObjectContextMenu.addToolTip()
        tooltip.description = getText("ContextMenu_Horse_IsRunning")
        gearOption.toolTip = tooltip
        return
    elseif not HorseUtils.isAdult(horse) then
        -- can't equip gear on a foal
        gearOption.notAvailable = true
        local tooltip = ISWorldObjectContextMenu.addToolTip()
        tooltip.description = getText("ContextMenu_Horse_NotAdult")
        gearOption.toolTip = tooltip
        return
    end

    
    local gearSubMenu = ISContextMenu:getNew(context)
    context:addSubMenu(gearOption, gearSubMenu)

    --- EQUIP OPTIONS
    local accessoriesCount = accessories:size()
    local uniques = {}
    local toAddOptionsTo = {}
    if accessoriesCount > 0 then
        -- early parse to cache uniques, with containers being considered uniques
        for i = 0, accessoriesCount - 1 do repeat
            local accessory = accessories:get(i)
            local displayName = accessory:getDisplayName()
            if not instanceof(accessory, "InventoryContainer")
                and uniques[displayName] then break end
            uniques[displayName] = true
            table.insert(toAddOptionsTo, {
                displayName = displayName, accessory = accessory, 
            })
        until true end

        table.sort(toAddOptionsTo, function(a, b)
            return a.displayName < b.displayName
        end)
        
        -- parse and add options to individual items
        for i = 1, #toAddOptionsTo do
            local accessoryData = toAddOptionsTo[i]
            local accessory = accessoryData.accessory
            local displayName = accessoryData.displayName

            -- format equip translation entry with item name
            local txt = HorseUtils.formatTemplate(
                getText("ContextMenu_Horse_Equip"),
                {new=displayName}
            )

            -- create the option to equip the accessory
            local option = gearSubMenu:addOption(
                txt,
                context,
                AttachmentsManager.equipAccessory,
                player,
                horse,
                accessory
            )
            option.iconTexture = accessory:getTexture()

            -- add a replace tooltip if slot is already occupied
            local slot = Attachments.getSlot(accessory:getFullType()) --[[@as AttachmentSlot]]
            local oldAccessory = Attachments.getAttachedItem(horse, slot)
            if oldAccessory then
                local tooltip = ISWorldObjectContextMenu.addToolTip()

                -- format replace translation entry with item name
                local txt = HorseUtils.formatTemplate(
                    getText("ContextMenu_Horse_Replace"),
                    {old=oldAccessory:getDisplayName(),new=accessory:getDisplayName()}
                )
                tooltip.description = txt
                option.toolTip = tooltip
            end
        end
    end


    --- UNEQUIP OPTIONS
    local attachedItems = Attachments.getAttachedItems(horse)
    local attachmentsCount = #attachedItems
    if attachmentsCount > 0 then
        -- sort by display name
        table.sort(attachedItems, function(a, b)
            -- sort direction is swapped here bcs we use "addOptionOnTop", so it adds in the inverse direction
            return a:getDisplayName() > b:getDisplayName()
        end)

        -- parse attachments and add unequip option
        for i = 1, attachmentsCount do
            local attachment = attachedItems[i] --[[@as InventoryItem]]

            -- format unequip translation entry with item name
            local txt = HorseUtils.formatTemplate(
                getText("ContextMenu_Horse_Unequip"),
                {old=attachment:getDisplayName()}
            )

            -- create the option to unequip the attachment
            local option = gearSubMenu:addOptionOnTop(
                txt,
                context,
                AttachmentsManager.unequipAccessory,
                player,
                horse,
                attachment
            )
            option.iconTexture = attachment:getTexture()
        end

        -- unequip all option if more than one item is present
        if attachmentsCount > 1 then
            gearSubMenu:addOptionOnTop(
                getText("ContextMenu_Horse_Unequip_All"),
                context,
                AttachmentsManager.unequipAllAccessory,
                player,
                horse,
                attachedItems
            )
        end
    end
end

---Main handler for horse context menu.
---@param playerNum integer
---@param context ISContextMenu
---@param animals IsoAnimal[]
AttachmentsManager.onClickedAnimalForContext = function(playerNum, context, animals)
    local player = getSpecificPlayer(playerNum)
    
    -- retrieve accessories in player inventory now to not call it for every animals
    local accessories = Attachments.getAvailableGear(player)
    
    for i = 1, #animals do repeat
        local animal = animals[i]
        if HorseUtils.isHorse(animal) then
            -- verify that the horse subcontext menu exists
            -- might not be necessary, but in-case another mod fucks around with it for X reasons
            local horseOption = context:getOptionFromName(animal:getFullName())
            if not horseOption or not horseOption.subOption then break end
            ---@cast horseOption umbrella.ISContextMenu.Option

            AttachmentsManager.populateHorseContextMenu(player, animal, context, accessories, horseOption)
        end
    until true end
end

Events.OnClickedAnimalForContext.Add(AttachmentsManager.onClickedAnimalForContext)

return AttachmentsManager