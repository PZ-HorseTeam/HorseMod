---@namespace HorseMod

---REQUIREMENTS
local Attachments = require("HorseMod/attachments/Attachments")
local ISHorseEquipGear = require("HorseMod/TimedActions/ISHorseEquipGear")
local ContainerManager = require("HorseMod/attachments/ContainerManager")

---Timed action for unequipping gear from a horse.
---@class ISHorseUnequipGear : ISHorseEquipGear
local ISHorseUnequipGear = ISHorseEquipGear:derive("HorseMod_ISHorseUnequipGear")

function ISHorseUnequipGear:complete()
    local horse = self.horse
    local character = self.character
    local accessory = self.accessory
    local slot = self.slot

    -- remove old accessory from slot and give to player or drop
    Attachments.setAttachedItem(horse, slot, nil)

    Actions.addOrDropItem(character, accessory)
    
    -- remove container
    local containerBehavior = self.attachmentDef.containerBehavior
    if containerBehavior then
        ContainerManager.removeContainer(character, horse, slot, accessory)
    end

    return true
end


function ISHorseUnequipGear:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end

    local unequipBehaviour = self.attachmentDef.unequipBehavior
    if not unequipBehaviour or not unequipBehaviour.time then
        return 120
    end

    return unequipBehaviour.time
end


function ISHorseUnequipGear:new(character, horse, accessory, slot, side, unlockPerform, unlockStop)
    local o = ISHorseEquipGear.new(self, character, horse, accessory, slot, side, unlockPerform, unlockStop) --[[@as ISHorseUnequipGear]]

    o.maxTime = o:getDuration()
    o.equipBehavior = o.attachmentDef.unequipBehavior or {}

    return o
end


_G[ISHorseUnequipGear.Type] = ISHorseUnequipGear


return ISHorseUnequipGear