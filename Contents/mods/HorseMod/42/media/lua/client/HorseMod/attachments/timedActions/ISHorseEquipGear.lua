---@namespace HorseMod

---REQUIREMENTS
local Attachments = require("HorseMod/attachments/Attachments")

---@class ISHorseEquipGear : ISBaseTimedAction
---@field horse IsoAnimal
---@field accessory InventoryItem
---@field attachmentDef AttachmentDefinition
---@field unlockFn fun()?
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
    if self.unlockFn then self.unlockFn() end
    ISBaseTimedAction.stop(self)
end

function ISHorseEquipGear:perform()
    if self.unlockFn then self.unlockFn() end
    ISBaseTimedAction.perform(self)
end

---@param character IsoGameCharacter
---@param horse IsoAnimal
---@param accessory InventoryItem
---@param unlockFn fun()?
---@return ISHorseEquipGear
---@nodiscard
function ISHorseEquipGear:new(character, horse, accessory, unlockFn)
    local o = ISBaseTimedAction.new(self, character) --[[@as ISHorseEquipGear]]
    o.horse   = horse
    o.accessory = accessory
    local attachmentDef = Attachments.getAttachmentDefinition(accessory:getFullType())
    o.maxTime = attachmentDef.equipTime
    o.attachmentDef = attachmentDef
    o.unlockFn = unlockFn
    o.stopOnWalk = true
    o.stopOnRun  = true
    o.stopOnAim  = true
    return o
end

return ISHorseEquipGear