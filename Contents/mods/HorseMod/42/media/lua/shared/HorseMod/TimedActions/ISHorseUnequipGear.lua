---@namespace HorseMod

---REQUIREMENTS
local Attachments = require("HorseMod/attachments/Attachments")
local ISHorseEquipGear = require("HorseMod/TimedActions/ISHorseEquipGear")
local ContainerManager = require("HorseMod/attachments/ContainerManager")

---@class ISHorseUnequipGear : ISHorseEquipGear
local ISHorseUnequipGear = ISHorseEquipGear:derive("ISHorseUnequipGear")

function ISHorseUnequipGear:perform()
    local horse = self.horse
    local character = self.character
    local accessory = self.accessory
    local attachmentDef = self.attachmentDef
    local slot = self.slot

    -- remove old accessory from slot and give to player or drop
    Attachments.setAttachedItem(horse, slot, nil)

    Attachments.giveBackToPlayerOrDrop(character, horse, accessory)
    
    -- init container
    local containerBehavior = attachmentDef.containerBehavior
    if containerBehavior then
        ContainerManager.removeContainer(character, horse, slot, accessory)
    end

    if self.unlockPerform then
        self.unlockPerform()
    end
    ISBaseTimedAction.perform(self)
end

---@param character IsoGameCharacter
---@param horse IsoAnimal
---@param accessory InventoryItem
---@param slot AttachmentSlot
---@param side string
---@param unlockPerform fun()?
---@param unlockStop fun()?
---@return ISHorseUnequipGear
---@nodiscard
function ISHorseUnequipGear:new(character, horse, accessory, slot, side, unlockPerform, unlockStop)
    local o = ISHorseEquipGear.new(self, character, horse, accessory, slot, side, unlockPerform, unlockStop) --[[@as ISHorseUnequipGear]]
    -- equip behavior
    local equipBehavior = o.attachmentDef.unequipBehavior or {}
    o.maxTime = equipBehavior.time or 90
    o.equipBehavior = equipBehavior
    return o
end

return ISHorseUnequipGear