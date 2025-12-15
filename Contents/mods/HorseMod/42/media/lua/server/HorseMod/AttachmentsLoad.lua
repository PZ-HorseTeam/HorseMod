local AttachmentData = require("HorseMod/attachments/AttachmentData")
local HorseUtils = require("HorseMod/Utils")
local AttachmentsLoad = {}

---@TODO refactor this file to use functions so other modders can also use it if needed



local containerItems = AttachmentData.containerItems
local scriptManager = getScriptManager()

local shouldError = false
---Used to log an error message for the HorseMod.
---@param message string
local function logError(message)
    DebugLog.log("HorseMod ERROR: "..message)
    shouldError = true
end

--- generate slot informations
local SLOT_DEFINITION = AttachmentData.slotsDefinitions
local slots = AttachmentData.slots
local maneSlots = AttachmentData.maneSlots
local group = AttachedLocations.getGroup("Animal")
for slot, slotData in pairs(SLOT_DEFINITION) do    
    -- verify the model attachment point
    local modelAttachment = slotData.modelAttachment
    assert(modelAttachment ~= nil, "No modelAttachment for a slot definition to link to the model attachment point.")

    -- create the apparel location
    local location = group:getOrCreateLocation(slot)
    location:setAttachmentName(modelAttachment)

    -- list slot in slots array
    table.insert(slots, slot)

    if slotData.isMane then
        local defaultMane = slotData.defaultMane
        assert(defaultMane ~= nil, "Slot ("..slot..") defined as mane without a default mane item.")
        maneSlots[slot] = defaultMane
    end
end


---Automatically generate the maneByBreed table from the mane definitions.
for breedName, hexTable in pairs(AttachmentData.MANE_HEX_BY_BREED) do
    AttachmentData.maneByBreed[breedName] = {
        hex = hexTable,
        maneConfig = AttachmentData.MANE_DEFAULT.maneConfig,
    }
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
            -- not a container
            if not accessoryScript:isItemType(ItemType.CONTAINER) then
                logError("Horse accessory ("..fullType..") cannot have a container behavior because it isn't of type 'Container'.")
                attachmentDef.containerBehavior = nil -- remove the container behavior as it cannot work
                break
            end

            -- log worldItem full type
            local worldItem = containerBehavior.worldItem
            containerItems[worldItem] = true

            -- verify the capacity of the world item and accessory are the same
            local worldItemScript = scriptManager:getItem(worldItem)
            if not worldItemScript then
                logError("Horse accessory ("..fullType..") has a container behavior with an invalid worldItem ("..worldItem..").")
                attachmentDef.containerBehavior = nil -- remove the container behavior as it cannot work
                break
            end

            local accessoryCapacity = HorseUtils.getJavaField(accessoryScript, "Capacity")
            local worldItemCapacity = HorseUtils.getJavaField(worldItemScript, "Capacity")
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
for fullType, _ in pairs(containerItems) do
    ISSearchManager.ignoredItemTypes[fullType] = true
end

return AttachmentsLoad