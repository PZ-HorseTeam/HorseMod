---@namespace HorseMod

local AttachmentData = require("HorseMod/attachments/AttachmentData")

local AttachmentVisuals = {}


---Retrieve the attached item on the specified `slot` of `animal`.
---@param animal IsoAnimal
---@param slot AttachmentSlot
---@return InventoryItem
---@nodiscard
function AttachmentVisuals.get(animal, slot)
    local attachedItems = animal:getAttachedItems()
    return attachedItems:getItem(slot)
end


---Retrieve a table with every attached items on the horse.
---@param animal IsoAnimal
---@return {item: InventoryItem, slot: AttachmentSlot}[]
---@nodiscard
function AttachmentVisuals.getAll(animal)
    local attached = {}
    local slots = AttachmentData.slots
    local maneSlots = AttachmentData.maneSlots
    for i = 1, #slots do
        local slot = slots[i]
        -- if not a mane, list it
        if not maneSlots[slot] then
            local attachment = AttachmentVisuals.get(animal, slot)
            if attachment then
                table.insert(attached, {item=attachment, slot=slot})
            end
        end
    end
    return attached
end


---Sets the visual for a slot to an item.
---@param animal IsoAnimal
---@param slot AttachmentSlot
---@param item InventoryItem?
function AttachmentVisuals.set(animal, slot, item)
    ---@diagnostic disable-next-line: param-type-mismatch
    animal:setAttachedItem(slot, item)
end


return AttachmentVisuals