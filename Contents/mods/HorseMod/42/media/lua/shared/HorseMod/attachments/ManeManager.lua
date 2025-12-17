---@namespace HorseMod

---REQUIREMENTS
local HorseUtils = require("HorseMod/Utils")
local Attachments = require("HorseMod/attachments/Attachments")
local AttachmentData = require("HorseMod/attachments/AttachmentData")
local rdm = newrandom()


---Table holding a RGB mane color.
---@class ManeColor
---@field r number
---@field g number
---@field b number

---Hold utility functions related to the horse manes.
local ManeManager = {}

---Check if the given slot is a mane slot.
---@param slot AttachmentSlot
---@return boolean
---@nodiscard
ManeManager.isManeSlot = function(slot)
    return AttachmentData.maneSlots[slot] ~= nil
end

---Retrieve the mane definition for a specific horse breed.
---@param breedName string
---@return ManeDefinition
---@nodiscard
ManeManager.getManeDefinition = function(breedName)
    local maneByBreed = AttachmentData.maneByBreed
    return maneByBreed[breedName] or AttachmentData.MANE_DEFAULT
end

---Generate a mane configuration and mane colors tables for a specific breed. The mane color needs to be the same for all mane slots.
---@param horse IsoAnimal
---@return table<AttachmentSlot, string> maneConfig
---@return table<AttachmentSlot, ManeColor> maneColors
ManeManager.generateManeConfig = function(horse)
    local breedName = HorseUtils.getBreedName(horse)
    local maneDef = ManeManager.getManeDefinition(breedName)
    local maneConfig = HorseUtils.tableCopy(maneDef.maneConfig)
    local maneColor = ManeManager.getManeColor(horse)
    local maneColors = {}
    for slot, _ in pairs(maneConfig) do
        maneColors[slot] = maneColor
    end
    return maneConfig, maneColors
end

---@FIXME only solution I found to avoid circular dependency while still keeping the function in this file since it's about manes
HorseUtils.generateManeConfig = ManeManager.generateManeConfig

---Remove manes from the horse.
---@param horse IsoAnimal
ManeManager.removeManes = function(horse)
    for slot, _ in pairs(AttachmentData.maneSlots) do
        local attached = Attachments.getAttachedItem(horse, slot)
        if attached then
            -- Attachments.setAttachedItem(horse, slot, nil)
            Attachments.removeAttachedItem(horse, attached)
        end
    end
end

---Select a random mane color for a specific horse breed based on possible mane colors.
---@param horse IsoAnimal
---@return ManeColor
---@nodiscard
ManeManager.getManeColor = function(horse)
    local breedName = HorseUtils.getBreedName(horse)
    local maneDef = ManeManager.getManeDefinition(breedName)
    local hexTable = maneDef.hex
    local hex = hexTable[rdm:random(1, #hexTable)]
    local r, g, b = HorseUtils.hexToRGBf(hex)

    return {r=r, g=g, b=b}
end

---Retrieve and set the mane color.
---@param horse IsoAnimal
---@param mane InventoryItem
---@param slot AttachmentSlot
---@param modData HorseModData
ManeManager.setupMane = function(horse, mane, slot, modData)
    -- access the mane color
    local maneColor = modData.maneColors[slot]

    -- verify the current colors are the right one, else set them
    if mane:getColorRed() ~= maneColor.r
        or mane:getColorGreen() ~= maneColor.g
        or mane:getColorBlue() ~= maneColor.b then
        mane:setColorRed(maneColor.r)
        mane:setColorGreen(maneColor.g)
        mane:setColorBlue(maneColor.b)
    end
    return mane
end


return ManeManager