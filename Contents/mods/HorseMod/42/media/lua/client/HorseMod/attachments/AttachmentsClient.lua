---@namespace HorseMod

---REQUIREMENTS
local HorseUtils = require("HorseMod/Utils")
local Attachments = require("HorseMod/attachments/Attachments")
local HorseEquipGear = require("HorseMod/TimedActions/HorseEquipGear")
local HorseUnequipGear = require("HorseMod/TimedActions/HorseUnequipGear")
local Mounts = require("HorseMod/Mounts")
local MountingUtility = require("HorseMod/mounting/MountingUtility")
local AttachmentData = require("HorseMod/attachments/AttachmentData")
local AnimationVariable = require("HorseMod/definitions/AnimationVariable")

local AttachmentsClient = {}


---Equip a new accessory on the horse.
---@param player IsoPlayer
---@param horse IsoAnimal
---@param accessory InventoryItem
---@param slot AttachmentSlot
---@param mountPosition MountPosition
AttachmentsClient.equipAccessory = function(player, horse, accessory, slot, mountPosition)
    MountingUtility.pathfindToHorse(player, horse, mountPosition)
    local side = mountPosition.name
    
    -- verify an attachment isn't already equiped, else unequip it
    local oldAccessory = Attachments.get(horse, slot)
    if oldAccessory then
        ISTimedActionQueue.add(HorseUnequipGear:new(player, horse, slot, side))
    end
    
    -- equip the attachment in hands
    local equipItemAction = ISEquipWeaponAction:new(player, accessory, 50, true, accessory:isTwoHandWeapon())
    equipItemAction.stopOnWalk = true
    equipItemAction.stopOnAim = true
    ISTimedActionQueue.add(equipItemAction)

    -- equip the attachment on horse
    ISTimedActionQueue.add(HorseEquipGear:new(player, horse, accessory, slot, side))
end

---Unequip a specific accessory on the horse.
---@param player IsoPlayer
---@param horse IsoAnimal
---@param slot AttachmentSlot
---@param mountPosition MountPosition
AttachmentsClient.unequipAccessory = function(player, horse, slot, mountPosition)
    MountingUtility.pathfindToHorse(player, horse, mountPosition)
    ISTimedActionQueue.add(HorseUnequipGear:new(player, horse, slot, mountPosition.name))
end

---Unequip every accessories on the horse.
---@param player IsoPlayer
---@param horse IsoAnimal
---@param oldAccessories {item: string, slot: AttachmentSlot}[]
---@param mountPosition MountPosition
AttachmentsClient.unequipAllAccessory = function(player, horse, oldAccessories, mountPosition)
    MountingUtility.pathfindToHorse(player, horse, mountPosition)
    
    -- unequip all
    for i = 1, #oldAccessories do
        local oldAccessory = oldAccessories[i]
        local slot = oldAccessory.slot
        ISTimedActionQueue.add(HorseUnequipGear:new(player, horse, slot, mountPosition.name))
    end
end


---@param character IsoGameCharacter
---@param animal IsoAnimal
---@return boolean canChange
---@return string? reason Translation string to display to user.
function AttachmentsClient.canChangeAttachments(character, animal)
    if animal:getVariableBoolean(AnimationVariable.GALLOP) then
        return false, "ContextMenu_Horse_IsRunning"
    end

    if not HorseUtils.isAdult(animal) then
        return false, "ContextMenu_Horse_NotAdult"
    end

    if Mounts.hasMount(character) then
        return false, "ContextMenu_Horse_CantChangeAttachmentsWhilePlayerMounted"
    end

    -- if Mounts.hasRider(animal) then
    --     return false, "ContextMenu_Horse_CantChangeAttachmentsWhileAnimalMounted"
    -- end

    return true
end


---@param context ISContextMenu
---@param player IsoPlayer
---@param accessories ArrayList<InventoryItem>
---@param horse IsoAnimal
---@param mountPosition MountPosition?
function AttachmentsClient.addEquipOptions(context, player, accessories, horse, mountPosition)
    --- EQUIP OPTIONS

    local accessoriesCount = accessories:size()

    ---@type {displayName: string, accessory: InventoryItem}[]
    local toAddOptionsTo = {}
    if accessoriesCount > 0 then
        -- early parse to cache uniques, with containers being considered uniques
        local uniques = {}
        for i = 0, accessoriesCount - 1 do repeat
            local accessory = accessories:get(i)

            -- skip if the accessory with the same name is already equipped
            -- but never skip if it's a container, as containers are considered unique
            local displayName = accessory:getDisplayName()
            if not instanceof(accessory, "InventoryContainer")
                and uniques[displayName] then break end

            -- store options and uniques
            uniques[displayName] = true
            table.insert(toAddOptionsTo, {
                displayName = displayName, accessory = accessory
            })
        until true end

        -- sort by display name
        table.sort(toAddOptionsTo, function(a, b)
            return a.displayName < b.displayName
        end)

        local hasMount = Mounts.hasRider(horse)
        
        -- parse and add options to individual items
        local uniqueCount = {} -- used to not list too many items of the same type
        for i = 1, #toAddOptionsTo do
            local accessoryData = toAddOptionsTo[i]
            local accessory = accessoryData.accessory
            local displayName = accessoryData.displayName

            -- for each slot possibility, add an option
            local fullType = accessory:getFullType()
            local slots = Attachments.getSlots(fullType)
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
                    AttachmentsClient.equipAccessory,
                    horse,
                    accessory,
                    slot,
                    mountPosition
                )
                option.iconTexture = accessory:getTexture()

                -- add a replace tooltip if slot is already occupied
                local oldAccessory = Attachments.get(horse, slot)
                if oldAccessory then
                    local tooltip = ISWorldObjectContextMenu.addToolTip()

                    -- format replace translation entry with item name
                    local txt = HorseUtils.formatTemplate(
                        getText("ContextMenu_Horse_Replace"),
                        {
                            old=getItemNameFromFullType(oldAccessory),
                            new=accessory:getDisplayName(),
                            slot=slot
                        }
                    )
                    tooltip.description = txt
                    option.toolTip = tooltip
                end

                -- first check that a mount position exists
                if not mountPosition then
                    option.notAvailable = true
                    local tooltip = ISWorldObjectContextMenu.addToolTip()
                    tooltip.description = getText("ContextMenu_Horse_NoMountPosition")
                    option.toolTip = tooltip

                -- check if the accessory can be equipped with a rider on the horse
                elseif hasMount and not Attachments.canEquipWithRider(accessory:getFullType(), slot) then
                    option.notAvailable = true
                    local tooltip = ISWorldObjectContextMenu.addToolTip()
                    tooltip.description = getText("ContextMenu_Horse_CannotEquipWithRider")
                    option.toolTip = tooltip
                end

                -- verify all the needed slots are occupied
                local respectsRequirements, missing = Attachments.verifyRequirements(horse, fullType, slot)
                if not respectsRequirements then
                    ---@cast missing -nil remove nil from possibilities
                    local requirementsAllOf = #missing.allOf > 0
                    local requirementsOneOf = #missing.oneOf > 0

                    -- main tooltip
                    local txt = getText("ContextMenu_Horse_Requirements_Missing")
                    
                    -- allOf tooltip
                    if requirementsAllOf then
                        local allOfTxt = HorseUtils.formatTemplate(
                            getText("ContextMenu_Horse_Requirements_AllOf"),
                            {allOf = table.concat(missing.allOf, ", ")}
                        )
                        txt = txt .. "\n" .. allOfTxt
                    end

                    -- oneOf tooltip
                    if requirementsOneOf then
                        local oneOfTxt = HorseUtils.formatTemplate(
                            getText("ContextMenu_Horse_Requirements_OneOf"),
                            {oneOf = table.concat(missing.oneOf, ", ")}
                        )
                        txt = txt .. "\n" .. oneOfTxt
                    end

                    local tooltip = ISWorldObjectContextMenu.addToolTip()
                    option.notAvailable = true
                    tooltip.description = txt
                    option.toolTip = tooltip
                end
            until true end
        end
    end
end


---@param context ISContextMenu
---@param player IsoPlayer
---@param attachedItems {item: string, slot: AttachmentSlot}[]
---@param horse IsoAnimal
---@param mountPosition MountPosition?
function AttachmentsClient.addUnequipOptions(context, player, attachedItems, horse, mountPosition)
    --- UNEQUIP OPTIONS
    if #attachedItems > 0 then
        -- sort by display name
        table.sort(attachedItems, function(a, b)
            -- sort direction is swapped here bcs we use "addOptionOnTop", so it adds in the inverse direction
            return getItemNameFromFullType(a.item) > getItemNameFromFullType(b.item)
        end)

        -- parse attachments and add unequip option
        local toUnequipAll = {}
        for i = 1, #attachedItems do
            local attachment = attachedItems[i]
            local item = attachment.item

            -- format unequip translation entry with item name
            local txt = HorseUtils.formatTemplate(
                getText("ContextMenu_Horse_Unequip"),
                {old=getItemNameFromFullType(item)}
            )

            -- create the option to unequip the attachment
            local option = context:addOptionOnTop(
                txt,
                player,
                AttachmentsClient.unequipAccessory,
                horse,
                attachment.slot,
                mountPosition
            )
            option.iconTexture = getTexture(getItemTextureName(item))

            -- can't reach a position to unequip the attachment
            if not mountPosition then
                option.notAvailable = true
                local tooltip = ISWorldObjectContextMenu.addToolTip()
                tooltip.description = getText("ContextMenu_Horse_NoMountPosition")
                option.toolTip = tooltip
            end

            -- verify this attachment is not the dependency of another attachment
            local hasDependencies, dependentAttachments = Attachments.findDependentAttachments(horse, attachment.item, attachment.slot)
            if hasDependencies then
                -- retrieve all dependencies
                local dependentAttachmentsNames = {}
                local allOf = dependentAttachments.allOf
                for j = 1, #allOf do
                    local dependentAttachment = allOf[j]
                    table.insert(dependentAttachmentsNames, getItemNameFromFullType(dependentAttachment.item))
                end

                local oneOf = dependentAttachments.oneOf
                for j = 1, #oneOf do
                    local dependentAttachment = oneOf[j]
                    table.insert(dependentAttachmentsNames, getItemNameFromFullType(dependentAttachment.item))
                end

                -- format tooltip
                local txt = HorseUtils.formatTemplate(
                    getText("ContextMenu_Horse_Unequip_HasDependencies"),
                    {dependentAttachments = table.concat(dependentAttachmentsNames, ", ")}
                )
                local tooltip = ISWorldObjectContextMenu.addToolTip()
                tooltip.description = txt
                option.notAvailable = true
                option.toolTip = tooltip
            else
                table.insert(toUnequipAll, attachment)
            end
        end

        -- unequip all option if more than one item is present
        if #toUnequipAll > 1 then
            local option = context:addOptionOnTop(
                getText("ContextMenu_Horse_Unequip_All"),
                player,
                AttachmentsClient.unequipAllAccessory,
                horse,
                toUnequipAll,
                mountPosition
            )

            if not mountPosition then
                option.notAvailable = true
                local tooltip = ISWorldObjectContextMenu.addToolTip()
                tooltip.description = getText("ContextMenu_Horse_NoMountPosition")
                option.toolTip = tooltip
            end
        end
    end
end


---Add the equip and unequip context menu options for horse gear.
---@param player IsoPlayer
---@param horse IsoAnimal
---@param context ISContextMenu
---@param accessories ArrayList<InventoryItem>
AttachmentsClient.populateHorseContextMenu = function(player, horse, context, accessories)
    local attachedItems = Attachments.getAll(horse)

    if accessories:size() < 1 and #attachedItems < 1 then
        return
    end

    -- create gear submenu, even if no gear is available
    local gearOption = context:addOption(getText("ContextMenu_Horse_Gear"))

    local canChangeGear, reason = AttachmentsClient.canChangeAttachments(player, horse)

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

    local mountPosition = MountingUtility.getNearestMountPosition(player, horse)

    AttachmentsClient.addEquipOptions(gearSubMenu, player, accessories, horse, mountPosition)
    AttachmentsClient.addUnequipOptions(gearSubMenu, player, attachedItems, horse, mountPosition)
end

---Main handler for horse context menu.
---@param playerNum integer
---@param context ISContextMenu
---@param animals IsoAnimal[]
AttachmentsClient.onClickedAnimalForContext = function(playerNum, context, animals)
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

            AttachmentsClient.populateHorseContextMenu(player, animal, horseSubMenu, accessories)
        end
    until true end
end

Events.OnClickedAnimalForContext.Add(AttachmentsClient.onClickedAnimalForContext)

return AttachmentsClient