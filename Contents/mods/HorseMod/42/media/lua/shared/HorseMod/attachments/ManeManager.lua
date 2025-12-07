---@namespace HorseMod

---REQUIREMENTS
local HorseUtils = require("HorseMod/Utils")
local Attachments = require("HorseMod/attachments/Attachments")
local AttachmentData = require("HorseMod/attachments/AttachmentData")

---Hold utility functions related to the horse manes.
local ManeManager = {}

---Remove manes from the horse.
---@param horse IsoAnimal
ManeManager.removeManes = function(horse)
    for slot, _ in pairs(AttachmentData.MANE_SLOTS_SET) do
        local attached = Attachments.getAttachedItem(horse, slot)
        if attached then
            -- Attachments.setAttachedItem(horse, slot, nil)
            Attachments.removeAttachedItem(horse, attached)
        end
    end
end

---Retrieve the mane color for a specific horse breed
---@param horse IsoAnimal
---@return ManeColor
---@nodiscard
ManeManager.getManeColor = function(horse)
    local breed = horse:getBreed()
    local breedName = breed:getName() or "_default"
    local hex = AttachmentData.MANE_HEX_BY_BREED[breedName]
    local r, g, b = HorseUtils.hexToRGBf(hex)

    return {r=r, g=g, b=b}
end

---Retrieve and set the mane color
---@param horse IsoAnimal
---@param mane InventoryItem
---@param slot AttachmentSlot
---@param _modData HorseModData|nil
ManeManager.setupMane = function(horse, mane, slot, _modData)
    local modData = _modData or HorseUtils.getModData(horse)
    local maneColor = modData.maneColors[slot]
    if not maneColor then
        maneColor = ManeManager.getManeColor(horse)
    end

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