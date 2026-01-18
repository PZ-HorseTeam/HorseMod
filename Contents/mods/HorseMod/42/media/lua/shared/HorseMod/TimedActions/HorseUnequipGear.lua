---@namespace HorseMod

---REQUIREMENTS
local Attachments = require("HorseMod/attachments/Attachments")
local HorseEquipGear = require("HorseMod/TimedActions/HorseEquipGear")
local ContainerManager = require("HorseMod/attachments/ContainerManager")

---Timed action for unequipping gear from a horse.
---@class HorseUnequipGear : HorseEquipGear
local HorseUnequipGear = HorseEquipGear:derive("HorseMod_HorseUnequipGear")

function HorseUnequipGear:complete()
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


function HorseUnequipGear:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end

    local unequipBehaviour = self.attachmentDef.unequipBehavior
    if not unequipBehaviour or not unequipBehaviour.time then
        return 120
    end

    return unequipBehaviour.time
end


function HorseUnequipGear:new(character, horse, accessory, slot, side)
    ---@type HorseUnequipGear
    local o = HorseEquipGear.new(self, character, horse, accessory, slot, side)

    o.maxTime = o:getDuration()
    o.equipBehavior = o.attachmentDef.unequipBehavior or {}

    return o
end


_G[HorseUnequipGear.Type] = HorseUnequipGear


return HorseUnequipGear