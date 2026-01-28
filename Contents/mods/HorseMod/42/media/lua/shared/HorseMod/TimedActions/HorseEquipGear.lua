---@namespace HorseMod

---REQUIREMENTS
local Attachments = require("HorseMod/attachments/Attachments")
local BaseGearAction = require("HorseMod/TimedActions/BaseGearAction")

---Timed action for equipping gear on a horse.
---@class HorseEquipGear : BaseGearAction
---@field accessory InventoryItem
---@field attachmentDef AttachmentDefinition
---@field equipBehavior EquipBehavior
---@field slot AttachmentSlot
---@field side string
local HorseEquipGear = BaseGearAction:derive("HorseMod_HorseEquipGear")


function HorseEquipGear:start()
    local equipBehavior = self.equipBehavior

    local anim = equipBehavior.anim
    local animationVar = anim and anim[self.side] or "Loot"
    self:setActionAnim(animationVar)

    -- should hold the accessory in hand when equipping
    if equipBehavior.shouldHold then
        self:setOverrideHandModels(self.accessory)
    end

    -- force face the horse
    self.character:faceThisObject(self.horse)
end


function HorseEquipGear:complete()
    -- player does not have the attachment
    if not self.character:getInventory():contains(self.accessory) then
        return false
    end

    -- already has an attachment in that slot
    if Attachments.get(self.horse, self.slot) ~= nil then
        return false
    end

    -- remove item from player's inventory
    local characterInventory = self.character:getInventory()
    characterInventory:Remove(self.accessory)
    sendRemoveItemFromContainer(characterInventory, self.accessory)
    sendEquip(self.character)

    -- init container
    local containerBehavior = self.attachmentDef.containerBehavior
    if containerBehavior then
        local ContainerManager = require("HorseMod/attachments/ContainerManager")
        ContainerManager.initContainer(
            self.character,
            self.horse,
            self.slot,
            containerBehavior,
            self.accessory
        )
    end

    -- set new accessory
    local AttachmentManager = require("HorseMod/attachments/AttachmentManager")
    AttachmentManager.setAttachedItem(self.horse, self.slot, self.accessory)

    return true
end


function HorseEquipGear:perform()
    local AttachmentVisuals = require("HorseMod/attachments/AttachmentVisuals")
    AttachmentVisuals.set(self.horse, self.slot, self.accessory)
    ISBaseTimedAction.perform(self)
end


function HorseEquipGear:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end

    local equipBehaviour = self.attachmentDef.equipBehavior
    if not equipBehaviour or not equipBehaviour.time then
        return 120
    end

    return equipBehaviour.time
end


---@param character IsoGameCharacter
---@param horse IsoAnimal
---@param accessory InventoryItem
---@param slot AttachmentSlot
---@param side string
---@return self
---@nodiscard
function HorseEquipGear:new(character, horse, accessory, slot, side)
    local o = BaseGearAction.new(self, character, horse) --[[@as HorseEquipGear]]
    o.accessory = accessory

    -- retrieve attachment informations
    local attachmentDef = Attachments.getAttachmentDefinition(accessory:getFullType(), slot)
    assert(attachmentDef ~= nil, "Accessory ("..accessory:getFullType()..") was passed to equip to a slot "..slot.." without an attachment definition for it, or isn't an attachment.")
    o.attachmentDef = attachmentDef
    o.slot = slot
    
    -- equip behavior
    o.maxTime = o:getDuration()
    o.equipBehavior = attachmentDef.equipBehavior or {}
    o.side = side

    return o
end


_G[HorseEquipGear.Type] = HorseEquipGear


return HorseEquipGear