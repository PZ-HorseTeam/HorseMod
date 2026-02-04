---@namespace HorseMod

local AttachmentData = require("HorseMod/attachments/AttachmentData")
local attachmentcommands = require("HorseMod/attachments/attachmentcommands")
local client = require("HorseMod/networking/client")
local commands = require("HorseMod/networking/commands")

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


client.registerCommandHandler(attachmentcommands.AttachmentChanged, function(args)
    local animal = commands.getAnimal(args.animal)
    if not animal then
        return
    end

    if args.item then
        AttachmentVisuals.set(animal, args.slot, instanceItem(args.item))
    else
        AttachmentVisuals.set(animal, args.slot, nil)
    end
end)


return AttachmentVisuals