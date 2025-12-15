---@namespace HorseMod

---REQUIREMENTS
local HorseUtils = require("HorseMod/Utils")
local HorseRegistries = require("HorseMod/HorseRegistries")
local AttachmentData = require("HorseMod/attachments/AttachmentData")
local ContainerManager = require("HorseMod/attachments/ContainerManager")

local rdm = newrandom()

---Holds utility functions related to the attachment system of horses.
local Attachments = {}

---Checks if the given item full type is an attachment, and optionally if it has a slot (`_slot`).
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
    local attachedItems = animal:getAttachedItems()
    return attachedItems and attachedItems:getItem(slot)
end

---Retrieve a table with every attached items on the horse.
---@param animal IsoAnimal
---@return {item: InventoryItem, slot: AttachmentSlot}[]
---@nodiscard
Attachments.getAttachedItems = function(animal)
    local attached = {}
    local slots = AttachmentData.slots
    local maneSlots = AttachmentData.maneSlots
    for i = 1, #slots do
        local slot = slots[i]
        -- if not a mane, list it
        if not maneSlots[slot] then
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
    sendAttachedItem(animal, slot, item) ---@diagnostic disable-line

    local modData = HorseUtils.getModData(animal)
    modData.bySlot[slot] = item and item:getFullType()
    animal:transmitModData()
end

---@param animal IsoAnimal
---@param item InventoryItem
Attachments.removeAttachedItem = function(animal, item)
    local attachedItems = animal:getAttachedItems()
    if attachedItems then
        local slot = attachedItems:getLocation(item) --[[@as AttachmentSlot]]
        attachedItems:remove(item)
        sendAttachedItem(animal, slot, nil) ---@diagnostic disable-line
        local modData = HorseUtils.getModData(animal)
        modData.bySlot[slot] = nil
        animal:transmitModData()
    end
end

Attachments.predicateHorseAccessory = function(item)
    local fullType = item:getFullType()
    return AttachmentData.items[fullType] ~= nil
end

---Retrieve every available attachments in the player inventory.
---@param player IsoPlayer
---@return ArrayList<InventoryItem>
---@nodiscard
Attachments.getAvailableGear = function(player)
    local playerInventory = player:getInventory()
    -- local accessories = playerInventory:getAllTag(HorseRegistries.HorseAccessory, ArrayList.new())
    local accessories = playerInventory:getAllEvalRecurse(Attachments.predicateHorseAccessory)
    return accessories
end

---Give the item to the player or drop it on the ground.
---@param player IsoPlayer?
---@param horse IsoAnimal
---@param item InventoryItem
Attachments.giveBackToPlayerOrDrop = function(player, horse, item)
    -- put in player inventory or drop on ground
    if player then
        Actions.addOrDropItem(player, item)
        return
    end

    -- the item should be dropped on the ground at random offsets to not have all the items stacked at the same coordinates
    local x, y, z = horse:getX(), horse:getY(), horse:getZ()
    local xr, yr = rdm:random(-1, 1), rdm:random(-1, 1)
    x, y = x + xr, y + yr

    -- try to retrieve the bottom square in case the attachments fall of a ledge for example
    -- this should also work if the horse is flying (dying in the air somehow)
    local square = HorseUtils.getBottom(x, y, z)
    
    ---@FIXME the logic behind retrieve the square could be flawed and drop the item in an invalid location
    ---This check serves as a fallback to avoid attachments disappearing, but a better solution should be found.
    if not square then
        getPlayer():getInventory():AddItem(item)
        return
    end

    -- place on the square at the random offsets
    square:AddWorldInventoryItem(
        item,
        x - math.floor(x),
        y - math.floor(y),
        0.0,
        true
    )
end

---Unequip instantly the attachment from the horse if it isn't a mane and store it in the player inventory or drop it on the ground.
---@param animal IsoAnimal
---@param slot AttachmentSlot
---@param player IsoPlayer?
Attachments.unequipAttachment = function(animal, slot, player)
    -- can't unequip mane items
    if AttachmentData.maneSlots[slot] then
        return
    end

    local current = Attachments.getAttachedItem(animal, slot)
    if not current then
        return
    end

    -- ignore if attachment should stay hidden from the player
    local attachmentDef = Attachments.getAttachmentDefinition(current:getFullType(), slot)
    assert(attachmentDef ~= nil, "Called unequip on an item ("..current:getFullType()..") that isn't an attachment or doesn't have an attachment definition for the slot "..slot..".")
    if not attachmentDef or attachmentDef.hidden or AttachmentData.maneSlots[slot] then
        return
    end
    
    Attachments.setAttachedItem(animal, slot, nil)
    Attachments.giveBackToPlayerOrDrop(player, animal, current)

    -- remove container
    local containerBehavior = attachmentDef.containerBehavior
    if containerBehavior then
        player = player or getPlayer() ---@TODO probably should change that to not be necessary
        ContainerManager.removeContainer(player, animal, slot, current)
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


-----GENERIC ATTACHMENT HELPERS-----

Attachments.getAttachedAndDef = function(animal, slot)
    local item = Attachments.getAttachedItem(animal, slot)
    if not item then return nil, nil end
    return item, Attachments.getAttachmentDefinition(item:getFullType(), slot)
end

---Retrieve the reins attachment item and its definition from the horse.
---@param animal IsoAnimal
---@return InventoryItem?
---@return AttachmentDefinition?
Attachments.getReins = function(animal)
    return Attachments.getAttachedAndDef(animal, "Reins")
end

---Retrieve the reins attachment item and its definition from the horse.
---@param animal IsoAnimal
---@return InventoryItem?
---@return AttachmentDefinition?
Attachments.getSaddle = function(animal)
    return Attachments.getAttachedAndDef(animal, "Saddle")
end


return Attachments