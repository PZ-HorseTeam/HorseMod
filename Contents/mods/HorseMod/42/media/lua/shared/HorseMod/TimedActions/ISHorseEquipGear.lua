---@namespace HorseMod

---REQUIREMENTS
local Attachments = require("HorseMod/attachments/Attachments")
local HorseUtils = require("HorseMod/Utils")
local ContainerManager = require("HorseMod/attachments/ContainerManager")

---@class ISHorseEquipGear : ISBaseTimedAction
---@field horse IsoAnimal
---@field accessory InventoryItem
---@field attachmentDef AttachmentDefinition
---@field equipBehavior EquipBehavior
---@field slot AttachmentSlot
---@field side string
---@field unlockPerform fun()?
---@field unlockStop fun()?
local ISHorseEquipGear = ISBaseTimedAction:derive("ISHorseEquipGear")

---@return boolean
function ISHorseEquipGear:isValid()
    return self.horse and self.horse:isExistInTheWorld()
end

function ISHorseEquipGear:start()
    local equipBehavior = self.equipBehavior
    
    -- set the action animation
    self.character:setVariable("EquipFinished", false)

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

function ISHorseEquipGear:update()
    self.character:faceThisObject(self.horse)

    -- end when
    local maxTime = self.maxTime
    if maxTime == -1 and self.character:getVariableBoolean("EquipFinished") then
        self:forceComplete()
    end
end

function ISHorseEquipGear:stop()
    if self.unlockStop then self.unlockStop() end
    ISBaseTimedAction.stop(self)
end

function ISHorseEquipGear:updateModData(horse, slot, ft, gr)
    local modData = HorseUtils.getModData(horse)
    modData.bySlot[slot] = ft
end

function ISHorseEquipGear:perform()
    local horse = self.horse
    local accessory = self.accessory
    local attachmentDef = self.attachmentDef
    local slot = self.slot

    -- remove item from player's inventory and add to horse inventory
    accessory:getContainer():Remove(accessory)

    -- init container
    local containerBehavior = attachmentDef.containerBehavior
    if containerBehavior then
        ContainerManager.initContainer(self.character, horse, slot, containerBehavior, accessory)
    end

    horse:getInventory():AddItem(accessory)

    -- set new accessory
    Attachments.setAttachedItem(horse, slot, accessory)
    self:updateModData(horse, slot, accessory:getFullType(), nil)

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
---@param unlockPerform fun()? should unlock after performing the action
---@param unlockStop fun()? unlock function when force stop the action, if unlockPerform is not provided
---@return ISHorseEquipGear
---@nodiscard
function ISHorseEquipGear:new(character, horse, accessory, slot, side, unlockPerform, unlockStop)
    local o = ISBaseTimedAction.new(self,character) --[[@as ISHorseEquipGear]]
    o.horse = horse
    o.accessory = accessory

    -- retrieve attachment informations
    local attachmentDef = Attachments.getAttachmentDefinition(accessory:getFullType(), slot)
    assert(attachmentDef ~= nil, "Accessory ("..accessory:getFullType()..") was passed to equip to a slot "..slot.." without an attachment definition for it, or isn't an attachment.")
    o.attachmentDef = attachmentDef
    o.slot = slot
    
    -- equip behavior
    local equipBehavior = attachmentDef.equipBehavior or {}
    o.maxTime = equipBehavior.time or 120
    o.equipBehavior = equipBehavior
    o.side = side

    -- unlock functions
    o.unlockPerform = unlockPerform
    o.unlockStop = unlockStop or unlockPerform

    -- default attachment actions
    o.stopOnWalk = true
    o.stopOnRun  = true
    o.stopOnAim  = true
    return o
end

return ISHorseEquipGear