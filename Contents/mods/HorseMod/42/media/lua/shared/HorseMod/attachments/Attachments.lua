---@namespace HorseMod

---REQUIREMENTS
local HorseUtils = require("HorseMod/Utils")
local AttachmentData = require("HorseMod/attachments/AttachmentData")
local HorseModData = require("HorseMod/HorseModData")

---Holds utility functions related to the attachment system of horses.
local Attachments = {}


---@class AttachmentsModData
---@field bySlot table<AttachmentSlot, string> Attachments full types associated to their slots of the horse.

local ATTACHMENTS_MOD_DATA = HorseModData.register--[[@<AttachmentsModData>]](
    "attachments",
    function(horse, modData)
        if not modData.bySlot then
            local breedName = HorseUtils.getBreedName(horse)
            local maneDef = Attachments.getManeDefinition(breedName)
            local maneConfig = copyTable(maneDef.maneConfig)
            modData.bySlot = maneConfig -- default mane config
        end

        -- cleanup invalid slots (i.e. removed slot)
        for slot, fullType in pairs(modData.bySlot) do
            if not Attachments.isSlot(slot) then
                local AttachmentManager = require("HorseMod/attachments/AttachmentManager")
                AttachmentManager.setAttachedItem(horse, slot, nil)
                AttachmentManager.giveBackToPlayerOrDrop(nil, horse, instanceItem(fullType))
            end
        end
    end
)
Attachments.ATTACHMENTS_MOD_DATA = ATTACHMENTS_MOD_DATA


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

---Checks if the given slot is a valid attachment slot.
---@param slot AttachmentSlot
---@return boolean
---@nodiscard
Attachments.isSlot = function(slot)
    return AttachmentData.slotsDefinitions[slot] ~= nil
end

---Retrieve the attachment slot of a given item fullType.
---@param fullType string
---@return AttachmentSlot[]
---@nodiscard
Attachments.getSlots = function(fullType)
    local itemDef = AttachmentData.items[fullType]
    local slots = {}
    for slot,_ in pairs(itemDef) do
        table.insert(slots, slot)
    end
    return slots
end

---@param fullType string
---@return AttachmentSlot
Attachments.getMainSlot = function(fullType)
    local slots = Attachments.getSlots(fullType)
    return slots[1] ---@diagnostic disable-line -- there should always be at least one slot
end

---Retrieve the mane definition for a specific horse breed.
---@param breedName string
---@return ManeDefinition
---@nodiscard
Attachments.getManeDefinition = function(breedName)
    local maneByBreed = AttachmentData.maneByBreed
    return maneByBreed[breedName] or AttachmentData.MANE_DEFAULT
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

---Gets the equipped attachment in a specific slot.
---@param animal IsoAnimal
---@param slot AttachmentSlot
---@return string? attachment Full type of the equipped attachment item. Nil if there is no attachment in that slot.
---@nodiscard
function Attachments.get(animal, slot)
    local bySlot = HorseModData.get(animal, Attachments.ATTACHMENTS_MOD_DATA).bySlot
    return bySlot[slot]
end

---Gets all currently equipped attachments.
---@param animal IsoAnimal
---@return {item: string, slot: AttachmentSlot}[] attachments Full type of equipped attachment items and the slot they are attached to.
---@nodiscard
function Attachments.getAll(animal)
    local bySlot = HorseModData.get(animal, Attachments.ATTACHMENTS_MOD_DATA).bySlot

    ---@type {item: string, slot: AttachmentSlot}[]
    local attachments = {}
    for slot, item in pairs(bySlot) do
        if not AttachmentData.maneSlots[slot] then
            attachments[#attachments + 1] = {item = item, slot = slot}
        end
    end
    return attachments
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

-----GENERIC ATTACHMENT HELPERS-----

---@param animal IsoAnimal
---@param slot AttachmentSlot
---@return string?
---@return AttachmentDefinition?
Attachments.getAttachedAndDef = function(animal, slot)
    local item = Attachments.get(animal, slot)
    if not item then
        return nil, nil
    end
    return item, Attachments.getAttachmentDefinition(item, slot)
end

---Retrieve the reins attachment item and its definition from the horse.
---@param animal IsoAnimal
---@return string?
---@return AttachmentDefinition?
Attachments.getReins = function(animal)
    return Attachments.getAttachedAndDef(animal, "Reins")
end

---Retrieve the reins attachment item and its definition from the horse.
---@param animal IsoAnimal
---@return string?
---@return AttachmentDefinition?
Attachments.getSaddle = function(animal)
    return Attachments.getAttachedAndDef(animal, "Saddle")
end

---Retrieve possible container information from the world item mod data. If it isn't a horse container, then nil should be returned.
---@param worldItem IsoWorldInventoryObject
---@return ContainerInformation?
function Attachments.getHorseContainerData(worldItem)
    local item = worldItem:getItem()
    if not item then return nil end
    local md_horse = item:getModData().HorseMod
    local container = md_horse and md_horse.container
    if container then
        return container
    end
    return nil
end


return Attachments