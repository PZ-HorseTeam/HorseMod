---@namespace HorseMod

---REQUIREMENTS
local HorseUtils = require("HorseMod/Utils")
local HorseRegistries = require("HorseMod/HorseRegistries")
local AttachmentData = require("HorseMod/attachments/AttachmentData")
local ContainerManager = require("HorseMod/attachments/ContainerManager")
local rdm = newrandom()

---Holds utility functions related to the attachment system of horses.
local Attachments = {}

---Checks if the given item full type is an attachment, and optionally if it has a slot `_slot`.
---@param fullType string
---@param _slot AttachmentSlot?
---@return boolean
---@nodiscard
Attachments.isAttachment = function(fullType, _slot)
    local itemDef = AttachmentData.items[fullType]
    if _slot then
        return itemDef and itemDef[_slot] ~= nil or false
    end
    return itemDef ~= nil
end

---Retrieve the attachment slot of a given item fullType.
---@param fullType string
---@return AttachmentSlot[]
---@nodiscard
Attachments.getSlots = function(fullType)
    local itemDef = AttachmentData.items[fullType]
    local slots = {}
    for slot,_ in pairs(itemDef) do
        if slot ~= "_count" then
            table.insert(slots, slot)
        end
    end
    return slots
end

---Retrieves the attachments associated to the given item full type.
---@param fullType string
---@param slot AttachmentSlot
---@return AttachmentDefinition?
---@nodiscard
Attachments.getAttachmentDefinition = function(fullType, slot)
    local itemDef = AttachmentData.items[fullType]
    return itemDef and itemDef[slot] or nil
end

---Retrieve the attached item on the specified `slot` of `animal`.
---@param animal IsoAnimal
---@param slot AttachmentSlot
---@return InventoryItem?
---@nodiscard
Attachments.getAttachedItem = function(animal, slot)
    local ai = animal:getAttachedItems()
    return ai and ai:getItem(slot)
end

---Retrieve a table with every attached items on the horse.
---@param animal IsoAnimal
---@return {item: InventoryItem, slot: AttachmentSlot}[]
---@nodiscard
Attachments.getAttachedItems = function(animal)
    local attached = {}
    local slots = AttachmentData.SLOTS
    local mane_slots_set = AttachmentData.MANE_SLOTS_SET
    for i = 1, #slots do
        local slot = slots[i]
        if not mane_slots_set[slot] then
            local attachment = Attachments.getAttachedItem(animal, slot)
            if attachment then
                table.insert(attached, {item=attachment, slot=slot})
            end
        end
    end
    return attached
end

---Attach an `item` or `nil` to a specific `slot` on the `animal`.
---@param animal IsoAnimal
---@param slot AttachmentSlot
---@param item InventoryItem?
Attachments.setAttachedItem = function(animal, slot, item)
    ---@diagnostic disable-next-line
    animal:setAttachedItem(slot, item)
    local modData = HorseUtils.getModData(animal)
    modData.bySlot[slot] = item and item:getFullType()
end

---@param animal IsoAnimal
---@param item InventoryItem
Attachments.removeAttachedItem = function(animal, item)
    local ai = animal:getAttachedItems()
    if ai then
        local slot = ai:getLocation(item) --[[@as AttachmentSlot]]
        ai:remove(item)
        local modData = HorseUtils.getModData(animal)
        modData.bySlot[slot] = nil
    end
end

---Retrieve every available attachments in the player inventory.
---@param player IsoPlayer
---@return ArrayList<InventoryItem>
---@nodiscard
Attachments.getAvailableGear = function(player)
    local playerInventory = player:getInventory()
    local accessories = playerInventory:getAllTag(HorseRegistries.HorseAccessory, ArrayList.new())
    return accessories
end

---Give the item to the player or drop it on the ground.
---@param player IsoPlayer?
---@param horse IsoAnimal
---@param item InventoryItem
Attachments.giveBackToPlayerOrDrop = function(player, horse, item)
    -- no item so ignore
    if not item then
        return
    end

    -- put in player inventory
    local pinv = player and player:getInventory()
    if pinv and pinv:addItem(item) then
        return
    end

    -- place on the square at random offsets
    local sq = horse:getSquare() or (player and player:getSquare())
    if sq then
        sq:AddWorldInventoryItem(item, rdm:random(0,1), rdm:random(0,1), 0.0)
    end
end

---Unequip instantly the attachment from the horse if it isn't a mane and store it in the player inventory or drop it on the ground.
---@param animal IsoAnimal
---@param slot AttachmentSlot
---@param player IsoPlayer?
Attachments.unequipAttachment = function(animal, slot, player)
    -- can't unequip mane items
    if AttachmentData.MANE_SLOTS_SET[slot] then
        return
    end
    local cur = Attachments.getAttachedItem(animal, slot)
    if not cur then
        return
    end

    -- ignore if attachment should stay hidden from the player
    local attachmentDef = Attachments.getAttachmentDefinition(cur:getFullType(), slot)
    assert(attachmentDef ~= nil, "Called unequip on an item ("..cur:getFullType()..") that isn't an attachment or doesn't have an attachment definition for the slot "..slot..".")
    if not attachmentDef or attachmentDef.hidden or AttachmentData.MANE_SLOTS_SET[slot] then
        return
    end
    
    Attachments.setAttachedItem(animal, slot, nil)
    Attachments.giveBackToPlayerOrDrop(player, animal, cur)

    -- remove container
    local containerBehavior = attachmentDef.containerBehavior
    if containerBehavior then
        player = player or getPlayer() ---@TODO probably should change that to not be necessary
        ContainerManager.removeContainer(player, animal, slot, cur)
    end
end

---Unequip all attachments of the horse and add to the player inventory or drop on the ground.
---@param animal IsoAnimal
---@param player IsoPlayer?
Attachments.unequipAllAttachments = function(animal, player)
    local modData = HorseUtils.getModData(animal)
    local bySlot = modData.bySlot
    for slot, fullType in pairs(bySlot) do
        Attachments.unequipAttachment(animal, slot, player)
    end
end

return Attachments