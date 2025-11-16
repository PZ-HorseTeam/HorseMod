local HorseUtils = require("HorseMod/Utils")
local AttachmentUtils = require("HorseMod/horse/attachments/AttachmentUtils")
local AttachmentLocations = require("HorseMod/horse/attachments/AttachmentLocations")


---@class HorseAttachmentManes
local HorseAttachmentManes = {}


local MANE_ITEM_BY_SLOT = AttachmentLocations.MANE_ITEM_BY_SLOT
local MANE_HEX_BY_BREED = AttachmentLocations.MANE_HEX_BY_BREED


---@nodiscard
---@param hex string|nil
---@return number, number, number
local function hexToRGBf(hex)
    if not hex then
        return 1, 1, 1
    end
    hex = tostring(hex):gsub("#", "")
    if #hex == 3 then
        hex = hex:sub(1, 1)
            .. hex:sub(1, 1)
            .. hex:sub(2, 2)
            .. hex:sub(2, 2)
            .. hex:sub(3, 3)
            .. hex:sub(3, 3)
    end
    if #hex ~= 6 then
        return 1, 1, 1
    end
    local r = (tonumber(hex:sub(1, 2), 16) or 255) / 255
    local g = (tonumber(hex:sub(3, 4), 16) or 255) / 255
    local b = (tonumber(hex:sub(5, 6), 16) or 255) / 255
    return r, g, b
end


---@param animal IsoAnimal|nil
function HorseAttachmentManes.ensureManesPresentAndColored(animal)
    if not (animal and HorseUtils.isHorse(animal)) then
        return
    end

    local inv = animal:getInventory()
    local bySlot, ground = AttachmentUtils.ensureHorseModData(animal)

    local md = animal:getModData()
    md.HM_Attach = md.HM_Attach or {}
    local perHorseHex = md.HM_Attach.maneHex
    local breed = animal:getBreed()
    local breedName = breed:getName()
    local hex = perHorseHex or (breedName and MANE_HEX_BY_BREED[breedName]) or MANE_HEX_BY_BREED.__default
    local r, g, b = hexToRGBf(hex)

    for slot, fullType in pairs(MANE_ITEM_BY_SLOT) do
        local it = AttachmentUtils.getAttachedItem(animal, slot)
        if not it and inv then
            it = inv:AddItem(fullType)
            if it then
                AttachmentUtils.setAttachedItem(animal, slot, it)
                bySlot[slot] = fullType
                ground[slot] = nil
            end
        end
        if it then
            if it:getColorRed() ~= r or it:getColorGreen() ~= g or it:getColorBlue() ~= b then
                it:setColorRed(r)
                it:setColorGreen(g)
                it:setColorBlue(b)
                AttachmentUtils.setAttachedItem(animal, slot, it)
            end
        end
    end
end

---@param item InventoryItem|nil
local function deleteInventoryItem(item)
    if not item then
        return
    end

    local container = item.getContainer and item:getContainer() or nil
    if container then
        if container.Remove then
            container:Remove(item)
        elseif container.DoRemoveItem then
            container:DoRemoveItem(item)
        end
    end

    local worldItem = item.getWorldItem and item:getWorldItem() or nil
    if worldItem then
        if worldItem.removeFromSquare then
            worldItem:removeFromSquare()
        end
        if worldItem.removeFromWorld then
            worldItem:removeFromWorld()
        end
    end
end

---@param animal IsoAnimal|nil
function HorseAttachmentManes.removeManesOnDeath(animal)
    if not (animal and HorseUtils.isHorse(animal)) then
        return
    end

    local bySlot, ground = AttachmentUtils.ensureHorseModData(animal)

    for slot, _ in pairs(MANE_ITEM_BY_SLOT) do
        local attached = AttachmentUtils.getAttachedItem(animal, slot)
        if attached then
            AttachmentUtils.setAttachedItem(animal, slot, nil)
            deleteInventoryItem(attached)
        end
        bySlot[slot] = nil
        ground[slot] = nil
    end
end

return HorseAttachmentManes
