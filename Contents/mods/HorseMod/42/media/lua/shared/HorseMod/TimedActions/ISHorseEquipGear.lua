---@namespace HorseMod

---REQUIREMENTS
local Attachments = require("HorseMod/Attachments")
local HorseUtils = require("HorseMod/Utils")

---@class ISHorseEquipGear : ISBaseTimedAction
---@field horse IsoAnimal
---@field accessory InventoryItem
---@field attachmentDef AttachmentDefinition
---@field unlockPerform fun()?
---@field unlockStop fun()?
local ISHorseEquipGear = ISBaseTimedAction:derive("ISHorseEquipGear")

---@return boolean
function ISHorseEquipGear:isValid()
    return self.horse and self.horse:isExistInTheWorld()
end

function ISHorseEquipGear:start()
    self:setActionAnim(self.attachmentDef.equipAnim or "Loot")
    self.character:faceThisObject(self.horse)
end

function ISHorseEquipGear:update()
    self.character:faceThisObject(self.horse)
end

function ISHorseEquipGear:stop()
    if self.unlockStop then self.unlockStop() end
    ISBaseTimedAction.stop(self)
end

---@param player IsoPlayer
---@param horse IsoAnimal
---@param item InventoryItem
function ISHorseEquipGear:giveBackToPlayerOrDrop(player, horse, item)
    -- player:getInventory():addItem(item)
    if not item then
        return
    end
    local pinv = player and player:getInventory()
    if pinv and pinv:addItem(item) then
        return
    end
    local sq = horse:getSquare() or (player and player:getSquare())
    if sq then
        sq:AddWorldInventoryItem(item, 0.0, 0.0, 0.0)
    end
end

function ISHorseEquipGear:updateModData(horse, slot, ft, gr)
    local modData = HorseUtils.getModData(horse)
    modData.bySlot[slot] = ft
    modData.ground[slot] = gr
end

function ISHorseEquipGear:perform()
    local horse = self.horse
    local player = self.character
    local accessory = self.accessory
    local attachmentDef = self.attachmentDef
    local slot = attachmentDef.slot

    -- remove item from player's inventory and add to horse inventory
    -- local hInv = horse:getInventory()
    -- local itemContainer = accessory:getContainer()
    accessory:getContainer():Remove(accessory)
    horse:getInventory():AddItem(accessory)

    -- remove old accessory from slot and give to player or drop
    local oldAccessory = Attachments.getAttachedItem(horse, slot)
    if oldAccessory then
        Attachments.setAttachedItem(horse, slot, nil)
        self:giveBackToPlayerOrDrop(player, horse, oldAccessory)
    end

    -- set new accessory
    Attachments.setAttachedItem(horse, slot, accessory)
    self:updateModData(horse, slot, accessory:getFullType(), nil)

    ---@TODO
    -- if slot == SADDLEBAG_SLOT then
    --     if ft == SADDLEBAG_FULLTYPE then
    --         HorseAttachmentSaddlebags.ensureSaddlebagContainer(animal, player, true)
    --         HorseAttachmentSaddlebags.moveVisibleToInvisibleOnAttach(player, animal)
    --         local d = HorseAttachmentSaddlebags.getSaddlebagData(animal)
    --         if d then
    --             d.equipped = true
    --         end
    --     else
    --         local d = HorseAttachmentSaddlebags.getSaddlebagData(animal)
    --         if d then
    --             d.equipped = false
    --         end
    --         HorseAttachmentSaddlebags.moveInvisibleToVisibleThenRemove(player, animal)
    --     end
    -- end

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
---@return ISHorseEquipGear
---@nodiscard
function ISHorseEquipGear:new(character, horse, accessory, unlockPerform, unlockStop)
    local o = ISBaseTimedAction.new(self,character) --[[@as ISHorseEquipGear]]
    o.horse = horse
    o.accessory = accessory
    local attachmentDef = Attachments.getAttachmentDefinition(accessory:getFullType())
    o.maxTime = attachmentDef.equipTime or 120
    o.attachmentDef = attachmentDef
    o.unlockPerform = unlockPerform
    o.unlockStop = unlockStop or unlockPerform
    o.stopOnWalk = true
    o.stopOnRun  = true
    o.stopOnAim  = true
    return o
end

return ISHorseEquipGear