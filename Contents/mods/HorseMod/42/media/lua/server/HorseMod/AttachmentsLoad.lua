local AttachmentData = require("HorseMod/attachments/AttachmentData")
local AttachmentsCheck = {}

local CONTAINER_ITEMS = AttachmentData.CONTAINER_ITEMS
local scriptManager = getScriptManager()

---Utility function to retrieve fields of specific Java object instances.
---@param object any
---@param field string
local function getJavaField(object, field)
    local offset = string.len(field)
    for i = 0, getNumClassFields(object) - 1 do
        local m = getClassField(object, i)
        if string.sub(tostring(m), -offset) == field then
            return getClassFieldVal(object, m)
        end
    end
    return nil -- no field found
end

local shouldError = false
---Used to log an error message for the HorseMod.
---@param message string
local function logError(message)
    DebugLog.log("HorseMod ERROR: "..message)
    shouldError = true
end

--- generate slot informations
local SLOT_DEFINITION = AttachmentData.SLOTS_DEFINITION
local SLOTS = AttachmentData.SLOTS
local MANE_SLOTS_SET = AttachmentData.MANE_SLOTS_SET
local group = AttachedLocations.getGroup("Animal")
for slot, slotData in pairs(SLOT_DEFINITION) do
    -- create the apparel location
    local location = group:getOrCreateLocation(slot)
    local modelAttachment = slotData.modelAttachment
    assert(modelAttachment ~= nil, "modelAttachment for a slot definition to link to the a model attachment point.")
    location:setAttachmentName(slotData.modelAttachment)

    -- list slot in slots array
    table.insert(SLOTS, slot)

    if slotData.isMane then
        local defaultMane = slotData.defaultMane
        assert(defaultMane ~= nil, "Slot ("..slot..") defined as mane without a default mane item.")
        MANE_SLOTS_SET[slot] = defaultMane
    end
end

---Verify specific conditions for every attachments.
for fullType, itemDef in pairs(AttachmentData.items) do
    local count = 0 -- count number of slots
    for slot, attachmentDef in pairs(itemDef) do repeat
        count = count + 1
        local accessoryScript = scriptManager:getItem(fullType)

        -- verify container behavior is compatible with this specific item
        local containerBehavior = attachmentDef.containerBehavior
        if containerBehavior then
            local type = accessoryScript:getType()
            -- not a container
            if type ~= Item.Type.Container then
                logError("Horse accessory ("..fullType..") cannot have a container behavior because it isn't of type 'Container'.")
                attachmentDef.containerBehavior = nil -- remove the container behavior as it cannot work
                break
            end

            -- log worldItem full type
            local worldItem = containerBehavior.worldItem
            CONTAINER_ITEMS[worldItem] = true

            -- verify the capacity of the world item and accessory are the same
            local worldItemScript = scriptManager:getItem(worldItem)
            local accessoryCapacity = getJavaField(accessoryScript, "Capacity")
            local worldItemCapacity = getJavaField(worldItemScript, "Capacity")
            if accessoryCapacity ~= worldItemCapacity then
                logError("Horse accessory ("..fullType..") doesn't have the same capacity as its 'worldItem' ("..worldItem..").")
                -- not removing the behavior bcs it technically still can work I believe, and would possibly break player attachment containers
                break
            end
        end
    until true end
    
    if count == 0 then
        AttachmentData.items[fullType] = nil
        logError("Horse accessory ("..fullType..") doesn't have any attachment definition for attachment slots but is defined as an attachment. Removing the item from the table for safety.")
    end
end

-- throw an error if needed.
if shouldError then
    error("Unexpected horse accessory data registered, see the console prints above.")
end

-- ignore invisible world items in the search menu
for fullType, _ in pairs(CONTAINER_ITEMS) do
    ISSearchManager.ignoredItemTypes[fullType] = true
end

return AttachmentsCheck