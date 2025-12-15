---@namespace HorseMod

---REQUIREMENTS
local Attachments = require("HorseMod/attachments/Attachments")
local ContainerManager = require("HorseMod/attachments/ContainerManager")
local AnimationVariables = require("HorseMod/AnimationVariables")

---@class ISHorseEquipGear : ISBaseTimedAction, umbrella.NetworkedTimedAction
---@field horse IsoAnimal
---@field accessory InventoryItem
---@field attachmentDef AttachmentDefinition
---@field equipBehavior EquipBehavior
---@field slot AttachmentSlot
---@field side string
---@field unlockPerform fun()?
---@field unlockStop fun()?
local ISHorseEquipGear = ISBaseTimedAction:derive("HorseMod_ISHorseEquipGear")

---@return boolean
function ISHorseEquipGear:isValid()
    return self.horse and self.horse:isExistInTheWorld()
end

function ISHorseEquipGear:start()
    local equipBehavior = self.equipBehavior
    
    -- set the action animation
    self.character:setVariable(AnimationVariables.EQUIP_FINISHED, false)

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
    if maxTime == -1 and self.character:getVariableBoolean(AnimationVariables.EQUIP_FINISHED) then
        self:forceComplete()
    end
end

function ISHorseEquipGear:stop()
    if self.unlockStop then self.unlockStop() end
    ISBaseTimedAction.stop(self)
end


function ISHorseEquipGear:perform()
    if self.unlockPerform then
        self.unlockPerform()
    end
    ISBaseTimedAction.perform(self)
end


function ISHorseEquipGear:complete()
    -- remove item from player's inventory and add to horse inventory
    local characterInventory = self.character:getInventory()
    characterInventory:Remove(self.accessory)
    sendRemoveItemFromContainer(characterInventory, self.accessory)
    sendEquip(self.character)

    local horseInventory = self.horse:getInventory()
    horseInventory:AddItem(self.accessory)
    sendAddItemToContainer(horseInventory, self.accessory)

    -- init container
    local containerBehavior = self.attachmentDef.containerBehavior
    if containerBehavior then
        ContainerManager.initContainer(
            self.character,
            self.horse,
            self.slot,
            containerBehavior,
            self.accessory
        )
    end

    -- set new accessory
    Attachments.setAttachedItem(self.horse, self.slot, self.accessory)

    return true
end


function ISHorseEquipGear:getDuration()
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
---@param unlockPerform fun()? should unlock after performing the action
---@param unlockStop fun()? unlock function when force stop the action, if unlockPerform is not provided
---@return self
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
    o.maxTime = o:getDuration()
    o.equipBehavior = attachmentDef.equipBehavior or {}
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


_G[ISHorseEquipGear.Type] = ISHorseEquipGear


return ISHorseEquipGear