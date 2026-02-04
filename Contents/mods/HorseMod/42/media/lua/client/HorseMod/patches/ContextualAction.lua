local Mounts = require("HorseMod/Mounts")
local Mounting = require("HorseMod/Mounting")
local Attachments = require("HorseMod/attachments/Attachments")
local AttachmentData = require("HorseMod/attachments/AttachmentData")
local AttachmentsClient = require("HorseMod/attachments/AttachmentsClient")
local MountingUtility = require("HorseMod/mounting/MountingUtility")

ContextualActionHandlers = ContextualActionHandlers or {}


local _originalAnimalsInteraction = ContextualActionHandlers.AnimalsInteraction
function ContextualActionHandlers.AnimalsInteraction(action, playerObj, animal, arg2, arg3, arg4)
    local mountPosition = MountingUtility.getNearestMountPosition(playerObj, animal)
    if mountPosition then
        ---DISMOUNT HORSE
        local mountedHorse = Mounts.getMount(playerObj)
        if mountedHorse == animal then
            if not playerObj:hasTimedActions() then
                Mounting.dismountHorse(playerObj, mountedHorse, mountPosition)
                return
            end
        end

        ---EQUIP ATTACHMENT IN HANDS ON HORSE
        local equipedItem = playerObj:getPrimaryHandItem()
        if equipedItem then
            local fullType = equipedItem:getFullType()
            if AttachmentData.items[fullType] then
                local slot = Attachments.getMainSlot(fullType)
                AttachmentsClient.equipAccessory(playerObj, animal, equipedItem, slot, mountPosition)
                return
            end
        end

        ---RIDE HORSE
        if MountingUtility.canMountHorse(playerObj, animal) and not playerObj:hasTimedActions() then
            local near = MountingUtility.getNearestMountPosition(playerObj, animal, 1.15)
            if near then
                playerObj:setIsAiming(false)
                Mounting.mountHorse(playerObj, animal, mountPosition)
                return
            end
        end
    end

    return _originalAnimalsInteraction(action, playerObj, animal, arg2, arg3, arg4)
end
