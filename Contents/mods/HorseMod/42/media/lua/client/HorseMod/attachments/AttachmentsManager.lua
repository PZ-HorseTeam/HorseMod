---@namespace HorseMod

---REQUIREMENTS
local HorseUtils = require("HorseMod/Utils")
local Attachments = require("HorseMod/attachments/Attachments")
local HorseEquipGear = require("HorseMod/TimedActions/HorseEquipGear")
local HorseUnequipGear = require("HorseMod/TimedActions/HorseUnequipGear")
local Mounts = require("HorseMod/Mounts")

local AttachmentsManager = {}


---Equip a new accessory on the horse.
---@param player IsoPlayer
---@param horse IsoAnimal
---@param accessory InventoryItem
---@param slot AttachmentSlot
AttachmentsManager.equipAccessory = function(player, horse, accessory, slot)
    local unlock, side = HorseUtils.pathfindToHorse(player, horse)
    
    -- verify an attachment isn't already equiped, else unequip it
    local oldAccessory = Attachments.getAttachedItem(horse, slot)
    if oldAccessory then
        ISTimedActionQueue.add(HorseUnequipGear:new(player, horse, oldAccessory, slot, side, nil, unlock))
    end
    
    -- equip the attachment in hands
    local equipItemAction = ISEquipWeaponAction:new(player, accessory, 50, true, accessory:isTwoHandWeapon())
    equipItemAction.stopOnWalk = true
    equipItemAction.stopOnAim = true
    ISTimedActionQueue.add(equipItemAction)

    -- equip the attachment on horse
    ISTimedActionQueue.add(HorseEquipGear:new(player, horse, accessory, slot, side, unlock))
end

---Unequip a specific accessory on the horse.
---@param player IsoPlayer
---@param horse IsoAnimal
---@param oldAccessory InventoryItem
---@param slot AttachmentSlot
AttachmentsManager.unequipAccessory = function(player, horse, oldAccessory, slot)
    local unlock, side = HorseUtils.pathfindToHorse(player, horse)
    ISTimedActionQueue.add(HorseUnequipGear:new(player, horse, oldAccessory, slot, side, unlock))
end

---Unequip every accessories on the horse.
---@param player IsoPlayer
---@param horse IsoAnimal
---@param oldAccessories {item: InventoryItem, slot: AttachmentSlot}[]
AttachmentsManager.unequipAllAccessory = function(player, horse, oldAccessories)
    local unlock, side = HorseUtils.pathfindToHorse(player, horse)
    
    -- unequip all
    for i = 1, #oldAccessories do
        local oldAccessory = oldAccessories[i]
        local item = oldAccessory.item
        local slot = oldAccessory.slot
        local shouldUnlockOnPerform = i == #oldAccessories and unlock or nil
        ISTimedActionQueue.add(HorseUnequipGear:new(player, horse, item, slot, side, shouldUnlockOnPerform, unlock))
    end
end


---@param character IsoGameCharacter
---@param animal IsoAnimal
---@return boolean canChange
---@return string? reason Translation string to display to user.
function AttachmentsManager.canChangeAttachments(character, animal)
    if animal:getVariableBoolean("animalRunning") then
        return false, "ContextMenu_Horse_IsRunning"
    end

    if not HorseUtils.isAdult(animal) then
        return false, "ContextMenu_Horse_NotAdult"
    end

    if Mounts.getMount(character) ~= nil then
        return false, "ContextMenu_Horse_CantChangeAttachmentsWhilePlayerMounted"
    end

    if Mounts.getRider(animal) ~= nil then
        return false, "ContextMenu_Horse_CantChangeAttachmentsWhileAnimalMounted"
    end

    return true
end


---@param context ISContextMenu
---@param player IsoPlayer
---@param accessories ArrayList<InventoryItem>
---@param horse IsoAnimal
function AttachmentsManager.addEquipOptions(context, player, accessories, horse)
    --- EQUIP OPTIONS
    local uniques = {}

    local accessoriesCount = accessories:size()

    ---@type {displayName: string, accessory: InventoryItem}[]
    local toAddOptionsTo = {}
    if accessoriesCount > 0 then
        -- early parse to cache uniques, with containers being considered uniques
        for i = 0, accessoriesCount - 1 do repeat
            local accessory = accessories:get(i)
            local displayName = accessory:getDisplayName()
            if not accessory or not instanceof(accessory, "InventoryContainer")
                and uniques[displayName] then break end
            ---@cast accessory InventoryContainer
            uniques[displayName] = true
            table.insert(toAddOptionsTo, {
                displayName = displayName, accessory = accessory
            })
        until true end

        -- sort by display name
        table.sort(toAddOptionsTo, function(a, b)
            return a.displayName < b.displayName
        end)
        
        -- parse and add options to individual items
        local uniqueCount = {} -- used to not list too many items of the same type
        for i = 1, #toAddOptionsTo do
            local accessoryData = toAddOptionsTo[i]
            local accessory = accessoryData.accessory
            local displayName = accessoryData.displayName

            -- for each slot possibility, add an option
            local slots = Attachments.getSlots(accessory:getFullType())
            for j = 1, #slots do repeat
                local slot = slots[j]

                local IDUnique = displayName..slot
                local lastCount = uniqueCount[IDUnique] or 0
                if lastCount >= 5 then break end
                uniqueCount[IDUnique] = lastCount + 1

                -- format equip translation entry with item name and slot
                local txt = HorseUtils.formatTemplate(
                    getText("ContextMenu_Horse_Equip"),
                    {new=displayName, slot=getText("ContextMenu_Horse_Slot_"..slot)}
                )

                -- create the option to equip the accessory
                local option = context:addOption(
                    txt,
                    player,
                    AttachmentsManager.equipAccessory,
                    horse,
                    accessory,
                    slot
                )
                option.iconTexture = accessory:getTexture()

                -- add a replace tooltip if slot is already occupied
                local oldAccessory = Attachments.getAttachedItem(horse, slot)
                if oldAccessory then
                    local tooltip = ISWorldObjectContextMenu.addToolTip()

                    -- format replace translation entry with item name
                    local txt = HorseUtils.formatTemplate(
                        getText("ContextMenu_Horse_Replace"),
                        {
                            old=oldAccessory:getDisplayName(),
                            new=accessory:getDisplayName(),
                            slot=slot
                        }
                    )
                    tooltip.description = txt
                    option.toolTip = tooltip
                end
            until true end
        end
    end
end


---@param context ISContextMenu
---@param player IsoPlayer
---@param attachedItems {item: InventoryItem, slot: AttachmentSlot}[]
---@param horse IsoAnimal
function AttachmentsManager.addUnequipOptions(context, player, attachedItems, horse)
    --- UNEQUIP OPTIONS
    if #attachedItems > 0 then
        -- sort by display name
        table.sort(attachedItems, function(a, b)
            -- sort direction is swapped here bcs we use "addOptionOnTop", so it adds in the inverse direction
            return a.item:getDisplayName() > b.item:getDisplayName()
        end)

        -- parse attachments and add unequip option
        for i = 1, #attachedItems do
            local attachment = attachedItems[i]
            local item = attachment.item

            -- format unequip translation entry with item name
            local txt = HorseUtils.formatTemplate(
                getText("ContextMenu_Horse_Unequip"),
                {old=item:getDisplayName()}
            )

            -- create the option to unequip the attachment
            local option = context:addOptionOnTop(
                txt,
                player,
                AttachmentsManager.unequipAccessory,
                horse,
                item, 
                attachment.slot
            )
            option.iconTexture = item:getTexture()
        end

        -- unequip all option if more than one item is present
        if #attachedItems > 1 then
            context:addOptionOnTop(
                getText("ContextMenu_Horse_Unequip_All"),
                player,
                AttachmentsManager.unequipAllAccessory,
                horse,
                attachedItems
            )
        end
    end
end


---Add the equip and unequip context menu options for horse gear.
---@param player IsoPlayer
---@param horse IsoAnimal
---@param context ISContextMenu
---@param accessories ArrayList<InventoryItem>
AttachmentsManager.populateHorseContextMenu = function(player, horse, context, accessories)
    local attachedItems = Attachments.getAttachedItems(horse)

    if accessories:size() < 1 and #attachedItems < 1 then
        return
    end

    -- create gear submenu, even if no gear is available
    local gearOption = context:addOption(getText("ContextMenu_Horse_Gear"))

    local canChangeGear, reason = AttachmentsManager.canChangeAttachments(player, horse)

    if not canChangeGear then
        if reason then
            local tooltip = ISWorldObjectContextMenu.addToolTip()
            tooltip.description = getText(reason)
            gearOption.toolTip = tooltip
        else
            print("[HorseMod] WEIRD: no reason returned for canChangeAttachments fail")
        end

        gearOption.notAvailable = true
        return
    end
    
    local gearSubMenu = ISContextMenu:getNew(context)
    context:addSubMenu(gearOption, gearSubMenu)

    AttachmentsManager.addEquipOptions(gearSubMenu, player, accessories, horse)
    AttachmentsManager.addUnequipOptions(gearSubMenu, player, attachedItems, horse)
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
            if not horseOption or not horseOption.subOption then
                break
            end

            local horseSubMenu = context:getSubMenu(horseOption.subOption)
            if not horseSubMenu then
                break
            end

            AttachmentsManager.populateHorseContextMenu(player, animal, horseSubMenu, accessories)
        end
    until true end
end

Events.OnClickedAnimalForContext.Add(AttachmentsManager.onClickedAnimalForContext)

---@param playerNum integer
---@param context ISContextMenu
---@param items InventoryItem[]|umbrella.ContextMenuItemStack[]
AttachmentsManager.OnFillInventoryObjectContextMenu = function(playerNum, context, items)
    -- get every single items
    local itemList = {}
    for i = 1,#items do
		local item = items[i]
		if not instanceof(item, "InventoryItem") then
            ---@cast item umbrella.ContextMenuItemStack
            local items = item.items
            for j = 1, #items do
                table.insert(itemList, items[j])
            end
        else
            table.insert(itemList, item)
        end
    end

    local equipOption = context:getOptionFromName(getText("ContextMenu_Equip_Primary"))
    local unequipOption = context:getOptionFromName(getText("ContextMenu_Equip_Secondary"))

    for i = 1, #itemList do repeat
        local item = itemList[i]
        
    until true end
end

Events.OnFillInventoryObjectContextMenu.Add(AttachmentsManager.OnFillInventoryObjectContextMenu)

return AttachmentsManager