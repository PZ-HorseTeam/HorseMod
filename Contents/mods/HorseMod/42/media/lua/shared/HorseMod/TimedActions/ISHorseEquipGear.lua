---@namespace HorseMod

---REQUIREMENTS
local Attachments = require("HorseMod/Attachments")

---@class ISHorseEquipGear : ISBaseTimedAction
---@field horse IsoAnimal
---@field accessory InventoryItem
---@field attachmentDef AttachmentDefinition
---@field unlockFn fun()?
local ISHorseEquipGear = ISBaseTimedAction:derive("ISHorseEquipGear")

---@return boolean
function ISHorseEquipGear:isValid()
print(self.horse and self.horse:isExistInTheWorld())
    return self.horse and self.horse:isExistInTheWorld()
end

function ISHorseEquipGear:start()
    print("start")
    self:setActionAnim(self.attachmentDef.equipAnim or "Loot")
    self.character:faceThisObject(self.horse)
end

function ISHorseEquipGear:update()
    print("update")
    self.character:faceThisObject(self.horse)
end

function ISHorseEquipGear:stop()
    print("stop")
    if self.unlockFn then self.unlockFn() end
    ISBaseTimedAction.stop(self)
end

---@param player IsoPlayer
---@param animal IsoAnimal
---@param item InventoryItem
function ISHorseEquipGear:giveBackToPlayerOrDrop(player, animal, item)
    player:getInventory():addItem(item)
    -- local sq = animal:getSquare() or player:getSquare()
    -- if sq then
    --     sq:AddWorldInventoryItem(item, 0.0, 0.0, 0.0)
    -- end
end

function ISHorseEquipGear:perform()
    print("perform")
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

    ---@TODO
    -- local bySlot, ground = AttachmentUtils.ensureHorseModData(animal)
    -- bySlot[slot] = ft
    -- ground[slot] = nil

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

    if self.unlockFn then
        self.unlockFn()
    end
    ISBaseTimedAction.perform(self)
end

---@param character IsoGameCharacter
---@param horse IsoAnimal
---@param accessory InventoryItem
---@param unlockFn fun()?
---@return ISHorseEquipGear
---@nodiscard
function ISHorseEquipGear:new(character, horse, accessory, unlockFn)
    print("new")
    local o = ISBaseTimedAction:new(character) --[[@as ISHorseEquipGear]]
    o.horse = horse
    o.accessory = accessory
    local attachmentDef = Attachments.getAttachmentDefinition(accessory:getFullType())
    o.maxTime = attachmentDef.equipTime or 120
    o.attachmentDef = attachmentDef
    o.unlockFn = unlockFn
    o.stopOnWalk = true
    o.stopOnRun  = true
    o.stopOnAim  = true
    return o
end

return ISHorseEquipGear