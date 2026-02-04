---@namespace HorseMod

---REQUIREMENTS
local HorseUtils = require("HorseMod/Utils")
local Attachments = require("HorseMod/attachments/Attachments")
local AttachmentData = require("HorseMod/attachments/AttachmentData")
local HorseModData = require("HorseMod/HorseModData")
local rdm = newrandom()


---Table holding a RGB mane color.
---@class ManeColor
---@field r number
---@field g number
---@field b number

---Hold utility functions related to the horse manes.
local ManeManager = {}

---@class ManesModData
---@field maneColors table<AttachmentSlot, ManeColor> Manes of the horse and their associated color.

local MANES_MOD_DATA = HorseModData.register--[[@<ManesModData>]](
    "manes",
    function(horse, modData)
        if not modData.maneColors then
            local maneColors = ManeManager.generateManeConfig(horse)
            modData.maneColors = maneColors
        end
    end
)
ManeManager.MANES_MOD_DATA = MANES_MOD_DATA

---Check if the given slot is a mane slot.
---@param slot AttachmentSlot
---@return boolean
---@nodiscard
ManeManager.isManeSlot = function(slot)
    return AttachmentData.maneSlots[slot] ~= nil
end

---Retrieve the mane definition for a specific horse breed.
---@deprecated
---@param breedName string
---@return ManeDefinition
---@nodiscard
ManeManager.getManeDefinition = function(breedName)
    local maneByBreed = AttachmentData.maneByBreed
    return maneByBreed[breedName] or AttachmentData.MANE_DEFAULT
end

---Generate a mane configuration and mane colors tables for a specific breed. The mane color needs to be the same for all mane slots.
---@param horse IsoAnimal
---@return table<AttachmentSlot, ManeColor> maneColors
ManeManager.generateManeConfig = function(horse)
    local breedName = HorseUtils.getBreedName(horse)
    local maneDef = Attachments.getManeDefinition(breedName)
    local maneConfig = maneDef.maneConfig
    local maneColor = ManeManager.getManeColor(horse)
    local maneColors = {}
    for slot, _ in pairs(maneConfig) do
        maneColors[slot] = maneColor
    end
    return maneColors
end

---Remove manes from the horse.
---@param horse IsoAnimal
ManeManager.removeManes = function(horse)
    -- TODO: move this to a server module as it requires server modules
    assert(not isClient(), "called server-only removeManes on client")
    for slot, _ in pairs(AttachmentData.maneSlots) do
        local AttachmentManager = require("HorseMod/attachments/AttachmentManager")
        AttachmentManager.setAttachedItem(horse, slot, nil)
    end
end

---Select a random mane color for a specific horse breed based on possible mane colors.
---@param horse IsoAnimal
---@return ManeColor
---@nodiscard
ManeManager.getManeColor = function(horse)
    local breedName = HorseUtils.getBreedName(horse)
    local maneDef = Attachments.getManeDefinition(breedName)
    local hexTable = maneDef.hex
    local hex = hexTable[rdm:random(1, #hexTable)]
    local r, g, b = HorseUtils.hexToRGBf(hex)

    return {r=r, g=g, b=b}
end

---Retrieve and set the mane color.
---@param horse IsoAnimal
---@param mane InventoryItem
---@param slot AttachmentSlot
ManeManager.setupMane = function(horse, mane, slot)
    -- access the mane color
    local maneColors = HorseModData.get(horse, MANES_MOD_DATA).maneColors
    local maneColor = maneColors[slot]
    local r, g, b = maneColor.r, maneColor.g, maneColor.b

    -- verify the current colors are the right one, else set them
    if mane:getColorRed() ~= r
        or mane:getColorGreen() ~= g
        or mane:getColorBlue() ~= b then
        mane:setColorRed(r)
        mane:setColorGreen(g)
        mane:setColorBlue(b)
    end
    return mane
end


return ManeManager