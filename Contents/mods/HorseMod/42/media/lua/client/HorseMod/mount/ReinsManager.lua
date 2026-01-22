---@namespace HorseMod

local Attachments = require("HorseMod/attachments/Attachments")
local AttachmentData = require("HorseMod/attachments/AttachmentData")
local AnimationVariable = require('HorseMod/definitions/AnimationVariable')

-- it might be better to redesign this as a generic attachment animator, but i'll leave that decision up to sim as he did most of the attachments design

---@class ReinsManager
---
---@field mount Mount
local ReinsManager = {}
ReinsManager.__index = ReinsManager


---@param mount IsoAnimal
---@param reinsItem InventoryItem
---@param state string
function ReinsManager:setState(mount, reinsItem, state)
    -- retrieve the model of reins model
    local fullType = reinsItem:getFullType()
    local attachmentDef = Attachments.getAttachmentDefinition(fullType, "Reins")
    assert(attachmentDef ~= nil, "equipped reins item has no definition")
    local model = attachmentDef.model
    assert(model ~= nil, "No rein model for item " .. tostring(fullType))

    -- retrieve the model associated to the current state
    local suffix = AttachmentData.REIN_STATES[state]
    assert(suffix ~= nil, "No suffix for specified state " .. tostring(state))

    local state_model = model .. AttachmentData.REIN_STATES[state]

    -- apply state model
    reinsItem:setStaticModel(state_model)
    mount:resetEquippedHandsModels()
end


function ReinsManager:update()
    local mountPair = self.mount.pair
    local mount = mountPair.mount
    local reinsItem = Attachments.getAttachedItem(mount, "Reins")
    
    if reinsItem then
        local movementState = self.mount.controller:getMovementState()

        self:setState(mount, reinsItem, movementState)

        --TODO these states should be defined when the rider mounts the horse
        mountPair.rider:setVariable(AnimationVariable.HAS_REINS, true)
    else
        mountPair.rider:setVariable(AnimationVariable.HAS_REINS, false)
    end
end


---@param mount Mount
function ReinsManager.new(mount)
    return setmetatable(
        {
            mount = mount
        },
        ReinsManager
    )
end


return ReinsManager