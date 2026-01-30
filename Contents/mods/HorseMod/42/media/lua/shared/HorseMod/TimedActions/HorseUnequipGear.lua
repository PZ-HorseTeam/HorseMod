---@namespace HorseMod

---REQUIREMENTS
local BaseGearAction = require("HorseMod/TimedActions/BaseGearAction")
local Attachments = require("HorseMod/attachments/Attachments")

---Timed action for unequipping gear from a horse.
---@class HorseUnequipGear : BaseGearAction
---@field attachmentDef AttachmentDefinition
---@field unequipBehavior EquipBehavior
---@field slot AttachmentSlot
---@field side string
local HorseUnequipGear = BaseGearAction:derive("HorseMod_HorseUnequipGear")


function HorseUnequipGear:start()
    local anim = self.unequipBehavior.anim
    local animationVar = anim and anim[self.side] or "Loot"
    self:setActionAnim(animationVar)

    -- i disabled this since i don't think it really makes sense for unequiping anyway? and it doesn't work in mp
    -- -- should hold the accessory in hand when equipping
    -- if self.unequipBehaviour.shouldHold then
    --     self:setOverrideHandModels(self.accessory)
    -- end

    -- force face the horse
    self.character:faceThisObject(self.horse)
end


function HorseUnequipGear:complete()
    local attachmentType = Attachments.get(self.horse, self.slot)
    if not attachmentType then
        return false
    end

    if self.character:DistToSquared(self.horse) > 1.5 then
        return false
    end

    local item = instanceItem(attachmentType)

    -- remove old accessory from slot and give to player or drop
    local AttachmentManager = require("HorseMod/attachments/AttachmentManager")
    AttachmentManager.setAttachedItem(self.horse, self.slot, nil)

    Actions.addOrDropItem(self.character, item)
    
    -- remove container
    local containerBehavior = self.attachmentDef.containerBehavior
    if containerBehavior then
        local ContainerManager = require("HorseMod/attachments/ContainerManager")
        ContainerManager.removeContainer(self.character, self.horse, self.slot, item)
    end

    return true
end


function HorseUnequipGear:perform()
    local AttachmentVisuals = require("HorseMod/attachments/AttachmentVisuals")
    AttachmentVisuals.set(self.horse, self.slot, nil)
    ISBaseTimedAction.perform(self)
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


---@param character IsoGameCharacter
---@param horse IsoAnimal
---@param slot AttachmentSlot
---@param side string
---@return HorseUnequipGear
---@nodiscard
function HorseUnequipGear:new(character, horse, slot, side)
    ---@type HorseUnequipGear
    local o = BaseGearAction.new(self, character, horse)

    o.slot = slot
    o.side = side

    local attachment = Attachments.get(horse, slot)
    assert(attachment ~= nil, "attempted to unequip accessory from empty slot " .. slot)
    local attachmentDef = Attachments.getAttachmentDefinition(attachment, slot)
    assert(attachmentDef ~= nil, "Accessory ("..attachment..") was passed to unequip to a slot "..slot.." without an attachment definition for it, or isn't an attachment.")
    o.attachmentDef = attachmentDef

    o.maxTime = o:getDuration()
    o.unequipBehavior = o.attachmentDef.unequipBehavior or {}

    return o
end


_G[HorseUnequipGear.Type] = HorseUnequipGear


return HorseUnequipGear