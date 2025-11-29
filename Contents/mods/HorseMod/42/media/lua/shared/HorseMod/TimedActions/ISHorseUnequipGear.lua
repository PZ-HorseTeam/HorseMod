---@namespace HorseMod

---REQUIREMENTS
local Attachments = require("HorseMod/Attachments")
local ISHorseEquipGear = require("HorseMod/TimedActions/ISHorseEquipGear")

---@class ISHorseUnequipGear : ISHorseEquipGear
---@field horse IsoAnimal
---@field oldAccessory InventoryItem
---@field attachmentDef AttachmentDefinition
---@field unlockFn fun()?
local ISHorseUnequipGear = ISHorseEquipGear:derive("ISHorseUnequipGear")

function ISHorseUnequipGear:start()
    self:setActionAnim(self.attachmentDef.unequipAnim or "Loot")
    self.character:faceThisObject(self.horse)
end

function ISHorseUnequipGear:perform()
    local horse = self.horse
    local player = self.character
    local accessory = self.accessory
    local attachmentDef = self.attachmentDef
    local slot = attachmentDef.slot

    -- remove old accessory from slot and give to player or drop
    Attachments.setAttachedItem(horse, slot, nil)

    self:updateModData(horse, slot, nil, nil)

    Attachments.giveBackToPlayerOrDrop(player, horse, accessory)

    if self.unlockPerform then
        self.unlockPerform()
    end
    ISBaseTimedAction.perform(self)
end

---@param character IsoGameCharacter
---@param horse IsoAnimal
---@param accessory InventoryItem
---@param unlockPerform fun()?
---@param unlockStop fun()?
---@return ISHorseUnequipGear
---@nodiscard
function ISHorseUnequipGear:new(character, horse, accessory, unlockPerform, unlockStop)
    local o = ISHorseEquipGear.new(self, character, horse, accessory, unlockPerform, unlockStop) --[[@as ISHorseUnequipGear]]
    o.maxTime = o.attachmentDef.unequipTime or 90
    return o
end

return ISHorseUnequipGear