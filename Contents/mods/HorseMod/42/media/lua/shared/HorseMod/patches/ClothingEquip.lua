---REQUIREMENTS
-- local HorseRiding = require("HorseMod/Riding")

--[[
This patch prevents players from equipping or unequipping certain clothing items while mounted on a horse.

API functions are provided in :lua:obj:`HorseMod/HorseAPI` to allow or restrict specific body locations while mounted.
]]
local ClothingEquip = {
    ---Table of allowed body locations to equip while mounted on a horse.
    ---@type table<string, boolean>
    allowedBodyLocations = {
        ["base:ammostrap"] = true,
        ["base:ankleholster"] = true,
        ["base:back"] = true,
        ["base:bandage"] = true,
        ["base:bathrobe"] = true,
        ["base:bellybutton"] = true,
        ["base:belt"] = true,
        ["base:beltextra"] = true,
        ["base:bodycostume"] = false,
        ["base:boilersuit"] = false,
        ["base:calf_left"] = false,
        ["base:calf_left_texture"] = false,
        ["base:calf_right"] = false,
        ["base:calf_right_texture"] = false,
        ["base:codpiece"] = false,
        ["base:cuirass"] = true,
        ["base:dress"] = false,
        ["base:ears"] = true,
        ["base:eartop"] = true,
        ["base:elbow_left"] = true,
        ["base:elbow_right"] = true,
        ["base:eyes"] = true,
        ["base:fannypackback"] = true,
        ["base:fannypackfront"] = true,
        ["base:forearm_left"] = true,
        ["base:forearm_right"] = true,
        ["base:fullhat"] = true,
        ["base:fullrobe"] = false,
        ["base:fullsuit"] = false,
        ["base:fullsuithead"] = false,
        ["base:fullsuitheadscba"] = false,
        ["base:fulltop"] = true,
        ["base:gaiter_left"] = false,
        ["base:gaiter_right"] = false,
        ["base:gorget"] = true,
        ["base:hands"] = true,
        ["base:handsleft"] = true,
        ["base:handsright"] = true,
        ["base:hat"] = true,
        ["base:jacket"] = true,
        ["base:jacket_bulky"] = true,
        ["base:jacket_down"] = true,
        ["base:jackethat"] = true,
        ["base:jackethat_bulky"] = true,
        ["base:jacketsuit"] = true,
        ["base:jersey"] = true,
        ["base:knee_left"] = false,
        ["base:knee_right"] = false,
        ["base:left_middlefinger"] = true,
        ["base:left_ringfinger"] = true,
        ["base:leftarm"] = true,
        ["base:lefteye"] = true,
        ["base:leftwrist"] = true,
        ["base:legs1"] = false,
        ["base:legs5"] = false,
        ["base:longdress"] = false,
        ["base:longskirt"] = false,
        ["base:makeup_eyes"] = true,
        ["base:makeup_eyesshadow"] = true,
        ["base:makeup_fullface"] = true,
        ["base:makeup_lips"] = true,
        ["base:mask"] = true,
        ["base:maskeyes"] = true,
        ["base:maskfull"] = true,
        ["base:neck"] = true,
        ["base:neck_texture"] = true,
        ["base:necklace"] = true,
        ["base:necklace_long"] = true,
        ["base:nose"] = true,
        ["base:pants"] = false,
        ["base:pants_skinny"] = false,
        ["base:pantsextra"] = false,
        ["base:right_middlefinger"] = true,
        ["base:right_ringfinger"] = true,
        ["base:rightarm"] = true,
        ["base:righteye"] = true,
        ["base:rightwrist"] = true,
        ["base:satchel"] = true,
        ["base:scarf"] = true,
        ["base:scba"] = true,
        ["base:scbanotank"] = true,
        ["base:shirt"] = true,
        ["base:shoes"] = false,
        ["base:shortpants"] = false,
        ["base:shortsleeveshirt"] = true,
        ["base:shortsshort"] = false,
        ["base:shoulderholster"] = true,
        ["base:shoulderpadleft"] = true,
        ["base:shoulderpadright"] = true,
        ["base:skirt"] = false,
        ["base:socks"] = false,
        ["base:sportshoulderpad"] = true,
        ["base:sportshoulderpadontop"] = true,
        ["base:sweater"] = true,
        ["base:sweaterhat"] = true,
        ["base:tail"] = true,
        ["base:tanktop"] = true,
        ["base:thigh_left"] = false,
        ["base:thigh_right"] = false,
        ["base:torso1legs1"] = false,
        ["base:torso1"] = true,
        ["base:torsoextra"] = true,
        ["base:torsoextravest"] = true,
        ["base:torsoextravestbullet"] = true,
        ["base:tshirt"] = true,
        ["base:underwear"] = false,
        ["base:underwearbottom"] = false,
        ["base:underwearextra1"] = false,
        ["base:underwearextra2"] = false,
        ["base:underweartop"] = true,
        ["base:vesttexture"] = true,
        ["base:webbing"] = true,
        ["base:wound"] = true,
        ["base:zeddmg"] = true,
    },

    ---Table of allowed blood locations to equip while mounted on a horse.
    ---@type table<string, boolean>
    allowedBloodLocations = {
        ["Apron"] = true,
        ["Bag"] = true,
        ["Foot_L"] = false,
        ["Foot_R"] = false,
        ["ForeArm_L"] = true,
        ["ForeArm_R"] = true,
        ["FullHelmet"] = true,
        ["Groin"] = false,
        ["Hand_L"] = true,
        ["Hand_R"] = true,
        ["Hands"] = true,
        ["Head"] = true,
        ["Jacket"] = true,
        ["Jumper"] = true,
        ["JumperNoSleeves"] = true,
        ["LongJacket"] = true,
        ["LowerArms"] = true,
        ["LowerBody"] = false,
        ["LowerLeg_L"] = false,
        ["LowerLeg_R"] = false,
        ["LowerLegs"] = false,
        ["Neck"] = true,
        ["Shirt"] = true,
        ["ShirtLongSleeves"] = true,
        ["ShirtNoSleeves"] = true,
        ["Shoes"] = false,
        ["ShortsShort"] = false,
        ["Trousers"] = false,
        ["UpperArm_L"] = true,
        ["UpperArm_R"] = true,
        ["UpperArms"] = true,
        ["UpperBody"] = true,
        ["UpperLeg_L"] = false,
        ["UpperLeg_R"] = false,
        ["UpperLegs"] = false,
    },
}

---@param item InventoryItem
---@return boolean
---@nodiscard
ClothingEquip.canEquipItem = function(item)
    -- check body locations
    local bodyLocation = item:getBodyLocation()
    if bodyLocation then
        local canEquip = ClothingEquip.allowedBodyLocations[tostring(bodyLocation)]
        if canEquip ~= nil then
            return canEquip
        end
    end

    -- check blood locations
    local bloodLocations = item:getBloodClothingType()
    if bloodLocations and bloodLocations:size() ~= 0 then
        -- check each blood location if they are allowed, and if one isn't then return false
        for i = 0, bloodLocations:size() - 1 do
            local bloodLocation = tostring(bloodLocations:get(i))
            if not ClothingEquip.allowedBloodLocations[bloodLocation] then
                return false
            end
        end

        return true
    end

    -- nothing to identify if the item can be equipped so false
    return false
end


ClothingEquip._originalWearClothingValid = ISWearClothing.isValid
function ISWearClothing:isValid()
    if self.item then
        if HorseRiding.isMountingHorse(self.character) then
            if not ClothingEquip.canEquipItem(self.item) then
                return false
            end
        end
    end
    return ClothingEquip._originalWearClothingValid(self)
end

ClothingEquip._originalUnequipValid = ISUnequipAction.isValid
function ISUnequipAction:isValid()
    if self.item then
        if HorseRiding.isMountingHorse(self.character) then
            if not ClothingEquip.canEquipItem(self.item) then
                return false
            end
        end
    end
    return ClothingEquip._originalUnequipValid(self)
end

return ClothingEquip
