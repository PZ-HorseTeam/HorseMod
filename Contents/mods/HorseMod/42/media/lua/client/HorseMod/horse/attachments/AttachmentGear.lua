local HorseUtils = require("HorseMod/Utils")
local AttachmentUtils = require("HorseMod/horse/attachments/AttachmentUtils")
local AttachmentLocations = require("HorseMod/horse/attachments/AttachmentLocations")
local HorseAttachmentSaddlebags = require("HorseMod/horse/attachments/AttachmentSaddlebags")
local HorseAttachmentManes = require("HorseMod/horse/attachments/AttachmentManes")


---@class HorseAttachmentGear
local HorseAttachmentGear = {}


local SLOTS = AttachmentLocations.SLOTS
local MANE_SLOTS_SET = AttachmentLocations.MANE_SLOTS_SET
local SADDLEBAG_SLOT = HorseAttachmentSaddlebags.SADDLEBAG_SLOT
local SADDLEBAG_FULLTYPE = HorseAttachmentSaddlebags.SADDLEBAG_FULLTYPE


---@nodiscard
---@param itemsMap HorseAttachmentItemsMap
---@param fullType string
---@return string|nil
function HorseAttachmentGear.slotFor(itemsMap, fullType)
    local def = itemsMap[fullType]
    if def == nil then
        return nil
    end
    local t = type(def)
    if t == "string" then
        return def
    elseif t == "table" then
        return def.slot
    end
    return nil
end


---@param player IsoPlayer
---@param animal IsoAnimal
---@param item InventoryItem
---@param itemsMap HorseAttachmentItemsMap
function HorseAttachmentGear.equipAttachment(player, animal, item, itemsMap)
    local ft = item:getFullType()
    local def = itemsMap[ft]
    if not def then
        return
    end
    local slot = (type(def) == "table") and def.slot or def

    local inv = animal:getInventory()
    if item:getContainer() ~= inv then
        local oldC = item:getContainer()
        if oldC then
            oldC:Remove(item)
        end
        inv:AddItem(item)
    end

    local old = AttachmentUtils.getAttachedItem(animal, slot)
    if old and old ~= item then
        AttachmentUtils.setAttachedItem(animal, slot, nil)
        AttachmentUtils.giveBackToPlayerOrDrop(player, animal, old)
    end

    AttachmentUtils.setAttachedItem(animal, slot, item)

    local bySlot, ground = AttachmentUtils.ensureHorseModData(animal)
    bySlot[slot] = ft
    ground[slot] = nil

    if slot == SADDLEBAG_SLOT then
        if ft == SADDLEBAG_FULLTYPE then
            HorseAttachmentSaddlebags.ensureSaddlebagContainer(animal, player, true)
            HorseAttachmentSaddlebags.moveVisibleToInvisibleOnAttach(player, animal)
            local d = HorseAttachmentSaddlebags.getSaddlebagData(animal)
            if d then
                d.equipped = true
            end
        else
            local d = HorseAttachmentSaddlebags.getSaddlebagData(animal)
            if d then
                d.equipped = false
            end
            HorseAttachmentSaddlebags.moveInvisibleToVisibleThenRemove(player, animal)
        end
    end
end


---@param player IsoPlayer|nil
---@param animal IsoAnimal
---@param slot string
function HorseAttachmentGear.unequipAttachment(player, animal, slot)
    if MANE_SLOTS_SET[slot] then
        return
    end
    local cur = AttachmentUtils.getAttachedItem(animal, slot)
    if not cur then
        return
    end
    if slot == SADDLEBAG_SLOT then
        HorseAttachmentSaddlebags.moveInvisibleToVisibleThenRemove(player, animal)
        local d = HorseAttachmentSaddlebags.getSaddlebagData(animal)
        if d then
            d.equipped = false
        end
    end

    AttachmentUtils.setAttachedItem(animal, slot, nil)

    local bySlot, ground = AttachmentUtils.ensureHorseModData(animal)
    bySlot[slot] = nil
    ground[slot] = nil

    AttachmentUtils.giveBackToPlayerOrDrop(player, animal, cur)
end


---@param player IsoPlayer
---@param animal IsoAnimal
function HorseAttachmentGear.unequipAll(player, animal)
    for i = 1, #SLOTS do
        local slot = SLOTS[i]
        HorseAttachmentGear.unequipAttachment(player, animal, slot)
    end
end


---@param animal IsoAnimal|nil
function HorseAttachmentGear.dropHorseGearOnDeath(animal)
    if not animal or (HorseUtils and not HorseUtils.isHorse(animal)) then
        return
    end

    HorseAttachmentSaddlebags.moveInvisibleToVisibleThenRemove(nil, animal)
    HorseAttachmentManes.removeManesOnDeath(animal)

    for i = 1, #SLOTS do
        local slot = SLOTS[i]
        if not MANE_SLOTS_SET[slot] and AttachmentUtils.getAttachedItem(animal, slot) then
            HorseAttachmentGear.unequipAttachment(nil, animal, slot)
        end
    end

    local bySlot, ground = AttachmentUtils.ensureHorseModData(animal)
    for i = 1, #SLOTS do
        local slot = SLOTS[i]
        if not MANE_SLOTS_SET[slot] then
            bySlot[slot] = nil
            ground[slot] = nil
        end
    end
    HorseAttachmentSaddlebags.disableTracking(animal)

    local md = animal:getModData()
    md.HM_Attach = md.HM_Attach or {}
    md.HM_Attach.DroppedOnDeath = true
end


---@param player IsoPlayer
---@param horse IsoAnimal
---@param workFn fun()
---@param maxTime integer
---@param context ISContextMenu
function HorseAttachmentGear.queueHorseGearAction(player, horse, workFn, maxTime, context)
    local unlock, lockDir = HorseUtils.lockHorseForInteraction(horse)
    context:closeAll()

    local lx, ly, lz = HorseUtils.getMountWorld(horse, "mountLeft")
    local rx, ry, rz = HorseUtils.getMountWorld(horse, "mountRight")
    local px, py     = player:getX(), player:getY()

    local dl = (px - lx) * (px - lx) + (py - ly) * (py - ly)
    local dr = (px - rx) * (px - rx) + (py - ry) * (py - ry)

    local tx, ty, tz = lx, ly, lz
    if dr < dl then
        tx, ty, tz = rx, ry, rz
    end

    local path
    if ISPathFindAction then
        path = ISPathFindAction:pathToLocationF(player, tx, ty, tz)
    end

    local function cleanupOnFail()
        unlock()
    end

    if path then
        path:setOnFail(cleanupOnFail)
        path.stop = function(self)
            cleanupOnFail()
            ISPathFindAction.stop(self)
        end
        path:setOnComplete(function()
            player:setDir(lockDir)
            ISTimedActionQueue.add(ISHorseGearAction:new(player, horse, workFn, maxTime, unlock))
        end)
        ISTimedActionQueue.add(path)
    else
        ISTimedActionQueue.add(ISHorseGearAction:new(player, horse, workFn, maxTime, unlock))
    end
end


HorseAttachmentSaddlebags.setDropOnDeathCallback(HorseAttachmentGear.dropHorseGearOnDeath)


return HorseAttachmentGear
