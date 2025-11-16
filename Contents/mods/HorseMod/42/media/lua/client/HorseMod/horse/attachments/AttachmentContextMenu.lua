local HorseUtils = require("HorseMod/Utils")
local HorseAttachmentGear = require("HorseMod/horse/attachments/AttachmentGear")
local AttachmentUtils = require("HorseMod/horse/attachments/AttachmentUtils")
local AttachmentLocations = require("HorseMod/horse/attachments/AttachmentLocations")


---@class HorseAttachmentContextMenu
local HorseAttachmentContextMenu = {}


---@type HorseAttachmentItemsMap|nil
local ITEMS_MAP = nil


---@param playerNum integer
---@param context ISContextMenu
---@param animals IsoAnimal[]
---@param test boolean
local function addAttachmentOptions(playerNum, context, animals, test)
    if test or not animals or #animals == 0 then
        return
    end

    local animal = animals[1]
    if not HorseUtils.isHorse(animal) then
        return
    end

    local player = getSpecificPlayer(playerNum)
    if not player then
        return
    end

    local horseOption = context:getOptionFromName(animal:getFullName())
    if not horseOption or not horseOption.subOption then
        return
    end

    local horseSubMenu = context:getSubMenu(horseOption.subOption)
    if not horseSubMenu then
        return
    end

    local itemsMap = ITEMS_MAP
    if not itemsMap then
        return
    end

    local gearRoot = horseSubMenu:addOption(getText("ContextMenu_Horse_Gear"))
    local gearSub  = ISContextMenu:getNew(context)
    context:addSubMenu(gearRoot, gearSub)

    local candidates = AttachmentUtils.collectCandidateItems(player, itemsMap)
    if #candidates > 0 then
        table.sort(candidates, function(a, b)
            local da = a:getDisplayName() or a:getFullType() or ""
            local db = b:getDisplayName() or b:getFullType() or ""
            if da == db then
                return a:getFullType() < b:getFullType()
            end
            return da:lower() < db:lower()
        end)

        local equipRoot = gearSub:addOption(getText("ContextMenu_Horse_Equip"))
        local equipSub  = ISContextMenu:getNew(context)
        context:addSubMenu(equipRoot, equipSub)

        for i = 1, #candidates do
            local it = candidates[i]
            local fullType = it:getFullType()
            local slot     = HorseAttachmentGear.slotFor(itemsMap, fullType)
            if slot and slot ~= "" then
                local current     = AttachmentUtils.getAttachedItem(animal, slot)
                local currentName = current and (current:getDisplayName() or slot)
                local name        = it:getDisplayName() or fullType
                local label       = current
                    and string.format(getText("ContextMenu_Horse_Replace") .. " " .. currentName .. " " .. getText("ContextMenu_Horse_With") .. " " .. name)
                    or  string.format(getText("ContextMenu_Horse_Equip") .. " " .. name)

                local opt = equipSub:addOption(label, player, function(p, a, obj)
                    HorseAttachmentGear.queueHorseGearAction(p, a, function()
                        HorseAttachmentGear.equipAttachment(p, a, obj, itemsMap)
                    end, 120, context)
                end, animal, it)

                opt.toolTip = ISWorldObjectContextMenu.addToolTip()
                opt.toolTip.description = string.format("%s: %s", getText("IGUI_Horse_Slot"), tostring(slot))
            end
        end
    else
        local noOpt = gearSub:addOption(getText("ContextMenu_Horse_No_Compatible_Gear"))
        noOpt.notAvailable = true
        if noOpt.setEnabled then
            noOpt:setEnabled(false)
        end
    end

    local anyEquipped = false
    for i = 1, #AttachmentLocations.SLOTS do
        local slot = AttachmentLocations.SLOTS[i]
        if not AttachmentLocations.MANE_SLOTS_SET[slot] and AttachmentUtils.getAttachedItem(animal, slot) then
            anyEquipped = true
            break
        end
    end

    if anyEquipped then
        local uneqRoot = gearSub:addOption(getText("ContextMenu_Horse_Unequip"))
        local uneqSub  = ISContextMenu:getNew(context)
        context:addSubMenu(uneqRoot, uneqSub)

        for i = 1, #AttachmentLocations.SLOTS do
            local slot = AttachmentLocations.SLOTS[i]
            if not AttachmentLocations.MANE_SLOTS_SET[slot] then
                local cur = AttachmentUtils.getAttachedItem(animal, slot)
                if cur then
                    local name = cur:getDisplayName() or slot
                    uneqSub:addOption(getText("ContextMenu_Horse_Unequip") .. " " .. name,
                        player,
                        function(p, a, s)
                            HorseAttachmentGear.queueHorseGearAction(p, a, function()
                                HorseAttachmentGear.unequipAttachment(p, a, s)
                            end, 90, context)
                        end,
                        animal, slot
                    )
                end
            end
        end

        uneqSub:addOption(getText("ContextMenu_Horse_Unequip_All"),
            player,
            function(p, a)
                HorseAttachmentGear.queueHorseGearAction(p, a, function()
                    HorseAttachmentGear.unequipAll(p, a)
                end, 150, context)
            end,
            animal
        )
    end
end


---@param itemsMap HorseAttachmentItemsMap
function HorseAttachmentContextMenu.init(itemsMap)
    ITEMS_MAP = itemsMap
    Events.OnClickedAnimalForContext.Add(addAttachmentOptions)
end


return HorseAttachmentContextMenu
