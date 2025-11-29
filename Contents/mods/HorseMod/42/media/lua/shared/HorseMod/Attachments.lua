---@namespace HorseMod

---REQUIREMENTS
local HorseUtils = require("HorseMod/Utils")
local AttachmentData = require("HorseMod/AttachmentData")
local rdm = newrandom()

local Attachments = {}

---Checks if the given item full type is an attachment, and optionally if it has a slot `_slot`.
---@param fullType string
---@param _slot string?
---@return boolean
---@nodiscard
Attachments.isAttachment = function(fullType, _slot)
    local attachmentDef = Attachments.items[fullType]
    if _slot then
        return attachmentDef and attachmentDef.slot == _slot or false
    end
    return attachmentDef ~= nil
end

---@param fullType string
---@return AttachmentSlot?
---@nodiscard
Attachments.getSlot = function(fullType)
    local def = AttachmentData.items[fullType]
    return def and def.slot
end

---Retrieves the attachments associated to the given item full type.
---@param fullType string
---@return AttachmentDefinition
---@nodiscard
Attachments.getAttachmentDefinition = function(fullType)
    return AttachmentData.items[fullType]
end

---Retrieve the attached item on the specified `slot` of `animal`.
---@param animal IsoAnimal
---@param slot AttachmentSlot
---@return InventoryItem?
---@nodiscard
Attachments.getAttachedItem = function(animal, slot)
    local ai = animal:getAttachedItems()
    return ai and ai:getItem(slot)
    -- return animal:getAttachedItem(slot)
end

---@param animal IsoAnimal
---@return InventoryItem[]
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
                table.insert(attached, attachment)
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
    local accessories = playerInventory:getAllTag("HorseAccessory", ArrayList.new())
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
    local attachmentDef = AttachmentData.items[cur:getFullType()]
    if attachmentDef and attachmentDef.hidden then
        return
    end

    -- if slot == SADDLEBAG_SLOT then
    --     HorseAttachmentSaddlebags.moveInvisibleToVisibleThenRemove(player, animal)
    --     local d = HorseAttachmentSaddlebags.getSaddlebagData(animal)
    --     if d then
    --         d.equipped = false
    --     end
    -- end

    Attachments.setAttachedItem(animal, slot, nil)
    Attachments.giveBackToPlayerOrDrop(player, animal, cur)
end

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