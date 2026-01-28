---@namespace HorseMod

---REQUIREMENTS
local Attachments = require("HorseMod/attachments/Attachments")
local ContainerManager = require("HorseMod/attachments/ContainerManager")
local AnimationEvent = require("HorseMod/definitions/AnimationEvent")

---Timed action for equipping gear on a horse.
---@class HorseEquipGear : ISBaseTimedAction, umbrella.NetworkedTimedAction
---@field horse IsoAnimal
---@field accessory InventoryItem
---@field attachmentDef AttachmentDefinition
---@field equipBehavior EquipBehavior
---@field slot AttachmentSlot
---@field side string
local HorseEquipGear = ISBaseTimedAction:derive("HorseMod_HorseEquipGear")

function HorseEquipGear:waitToStart()
    local character = self.character
    character:faceThisObject(self.horse)
    return character:shouldBeTurning()
end

---@return boolean
function HorseEquipGear:isValid()
    return self.horse and self.horse:isExistInTheWorld()
end

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

function HorseEquipGear:serverStart()
    ---@diagnostic disable-next-line: param-type-mismatch
    emulateAnimEventOnce(self.netAction, 1000, AnimationEvent.EQUIP_FINISHED, nil)
    return true
end

function HorseEquipGear:update()
    local horse = self.horse
    local character = self.character
    character:faceThisObject(horse)
    horse:getPathFindBehavior2():reset()
end


function HorseEquipGear:animEvent(event, parameter)
    if event == AnimationEvent.EQUIP_FINISHED then
        if isServer() then
            ---@diagnostic disable-next-line: need-check-nil
            self.netAction:forceComplete()
        else
            self:forceComplete()
        end
    end
end


function HorseEquipGear:complete()
    -- remove item from player's inventory and add to horse inventory
    local characterInventory = self.character:getInventory()
    characterInventory:Remove(self.accessory)
    sendRemoveItemFromContainer(characterInventory, self.accessory)
    sendEquip(self.character)

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

    -- add the item to the horse inventory
    local horseInventory = self.horse:getInventory()
    horseInventory:AddItem(self.accessory)
    sendAddItemToContainer(horseInventory, self.accessory)

    -- set new accessory
    Attachments.setAttachedItem(self.horse, self.slot, self.accessory)

    return true
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
    local o = ISBaseTimedAction.new(self,character) --[[@as HorseEquipGear]]
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

    -- default attachment actions
    o.stopOnWalk = true
    o.stopOnRun  = true
    o.stopOnAim  = true
    return o
end


_G[HorseEquipGear.Type] = HorseEquipGear


return HorseEquipGear