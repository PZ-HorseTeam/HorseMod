if isClient() then
    return
end

---@namespace HorseMod

local Attachments = require("HorseMod/attachments/Attachments")
local AttachmentData = require("HorseMod/attachments/AttachmentData")
local ContainerManager = require("HorseMod/attachments/ContainerManager")
local HorseModData = require("HorseMod/HorseModData")
local HorseUtils = require("HorseMod/Utils")
local attachmentcommands = require("HorseMod/attachments/attachmentcommands")
local commands = require("HorseMod/networking/commands")

local rdm = newrandom()

local AttachmentManager = {}

---Attach an `item` or `nil` to a specific `slot` on the `animal`.
---@param animal IsoAnimal
---@param slot AttachmentSlot
---@param item InventoryItem?
AttachmentManager.setAttachedItem = function(animal, slot, item)
    local bySlot = HorseModData.get(animal, Attachments.ATTACHMENTS_MOD_DATA).bySlot
    bySlot[slot] = item and item:getFullType()
    animal:transmitModData()

    if isServer() then
        attachmentcommands.AttachmentChanged:send(nil, {animal = commands.getAnimalId(animal), slot = slot, item = bySlot[slot]})
    end
end

---Give the item to the player or drop it on the ground.
---@param player IsoPlayer?
---@param horse IsoAnimal
---@param item InventoryItem
AttachmentManager.giveBackToPlayerOrDrop = function(player, horse, item)
    -- put in player inventory or drop on ground
    if player then
        Actions.addOrDropItem(player, item)
        return
    end

    -- the item should be dropped on the ground at random offsets to not have all the items stacked at the same coordinates
    local x, y, z = horse:getX(), horse:getY(), horse:getZ()
    local xr, yr = rdm:random(-1, 1), rdm:random(-1, 1)
    x, y = x + xr, y + yr

    -- try to retrieve the bottom square in case the attachments fall of a ledge for example
    -- this should also work if the horse is flying (dying in the air somehow)
    local square = HorseUtils.getBottom(x, y, z)
    
    ---@FIXME this can't work server side and will throw an error 
    ---the logic behind retrieve the square could be flawed and drop the item in an invalid location
    ---This check serves as a fallback to avoid attachments disappearing, but a better solution should be found.
    if not square then
        getPlayer():getInventory():AddItem(item)
        return
    end

    -- place on the square at the random offsets
    square:AddWorldInventoryItem(
        item,
        x - math.floor(x),
        y - math.floor(y),
        0.0,
        true
    )
end

---Unequip instantly the attachment from the horse if it isn't a mane and store it in the player inventory or drop it on the ground.
---@param animal IsoAnimal
---@param slot AttachmentSlot
---@param player IsoPlayer?
AttachmentManager.unequipAttachment = function(animal, slot, player)
    -- can't unequip mane items
    if AttachmentData.maneSlots[slot] then
        return
    end

    local current = Attachments.get(animal, slot)
    if not current then
        return
    end

    -- ignore if attachment should stay hidden from the player
    local attachmentDef = Attachments.getAttachmentDefinition(current, slot)
    assert(attachmentDef ~= nil, "Called unequip on an item ("..current..") that isn't an attachment or doesn't have an attachment definition for the slot "..slot..".")
    if not attachmentDef or attachmentDef.hidden or AttachmentData.maneSlots[slot] then
        return
    end

    local item = instanceItem(current)
    
    AttachmentManager.setAttachedItem(animal, slot, nil)
    AttachmentManager.giveBackToPlayerOrDrop(player, animal, item)

    -- remove container
    local containerBehavior = attachmentDef.containerBehavior
    if containerBehavior then
        player = player or getPlayer() ---@TODO probably should change that to not be necessary
        ContainerManager.removeContainer(player, animal, slot, item)
    end
end

---Unequip all attachments of the horse and add to the player inventory or drop on the ground.
---@param animal IsoAnimal
---@param player IsoPlayer?
AttachmentManager.unequipAllAttachments = function(animal, player)
    local bySlot = HorseModData.get(animal, Attachments.ATTACHMENTS_MOD_DATA).bySlot
    for slot, fullType in pairs(bySlot) do
        AttachmentManager.unequipAttachment(animal, slot, player)
    end
end

return AttachmentManager