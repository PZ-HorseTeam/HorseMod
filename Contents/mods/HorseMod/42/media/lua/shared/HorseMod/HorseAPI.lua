---@namespace HorseMod

---REQUIREMENTS
local ClothingEquip = require("HorseMod/patches/ClothingEquip")
local AttachmentData = require("HorseMod/attachments/AttachmentData")

---Provides API functions to interact with various HorseMod systems.
local HorseAPI = {}


---Add a body location restriction while mounting a horse. By default, body locations are restricted from being equipped/unequipped while mounted unless explicitly allowed in the ClothingEquip.allowedLocations table.
HorseAPI.addBodyLocationRestriction = function(bodyLocation, canEquip)
    ClothingEquip.allowedLocations[bodyLocation] = canEquip
end



---Used to define new attachments.
---@param itemDefinitions table<string,ItemDefinition>
HorseAPI.addNewAttachments = function(itemDefinitions)
    for fullType, itemDef in pairs(itemDefinitions) do
        for slot, attachmentDef in pairs(itemDef) do
            HorseAPI.addNewAttachment(fullType, slot, attachmentDef)
        end
    end
end

---@param fullType string
---@param slot AttachmentSlot
---@param attachmentDef AttachmentDefinition
HorseAPI.addNewAttachment = function(fullType, slot, attachmentDef)
    -- retrieve item definition
    local items = AttachmentData.items
    local itemDefEntry = items[fullType] or {}

    -- set or overwrite
    local attachmentDefEntry = itemDefEntry[slot]
    assert(not attachmentDefEntry, "AttachmentData.addNewAttachment: Attachment for item '" .. fullType .. "' on slot '" .. slot .. "' already exists!")

    itemDefEntry[slot] = attachmentDef
    items[fullType] = itemDefEntry
end

---Used to define a new attachment slot.
---@param slot AttachmentSlot
---@param slotDefinition SlotDefinition
HorseAPI.addNewSlot = function(slot, slotDefinition)
    local slotsDef = AttachmentData.slotsDefinitions
    assert(not slotsDef[slot], "AttachmentData.addNewSlot: Slot '" .. slot .. "' already exists!")

    slotsDef[slot] = slotDefinition
end

---XYZ coordinate table.
---@alias XYZ {x: number, y: number, z: number}


---Used to add a new model `attachment point <https://pzwiki.net/wiki/Attachment_(scripts)>`_ to the horse model script via Lua. This attachment point can then be used in :lua:obj:`HorseMod.attachments.AttachmentData.slotsDefinitions` to define new attachment slots on a custom position on the horse.
---@param modelAttachment string Attachment point name.
---@param attachmentData {bone: string, offset: XYZ, rotate: XYZ}
HorseAPI.addNewModelAttachment = function(modelAttachment, attachmentData)
    local horseModelScript = getScriptManager():getModelScript("HorseMod.Horse")

    -- verify this attachment point does not already exist
    local attachmentPoint = horseModelScript:getAttachmentById(modelAttachment)
    assert(attachmentPoint == nil, "AttachmentData.addNewModelAttachment: Attachment point '" .. modelAttachment .. "' already exists!")

    -- create a new attachment point
    local attachmentPoint = ModelAttachment.new(modelAttachment)
    attachmentPoint:setBone(attachmentData.bone)
    
    -- set offset
    local offset = attachmentData.offset
    if offset then
        local v3 = attachmentPoint:getOffset()
        v3:set(offset.x, offset.y, offset.z)
    end

    -- set rotation
    local rotate = attachmentData.rotate
    if rotate then
        local v3 = attachmentPoint:getRotate()
        v3:set(rotate.x, rotate.y, rotate.z)
    end

    -- save attachment point
    horseModelScript:addAttachment(attachmentPoint)
end


return HorseAPI