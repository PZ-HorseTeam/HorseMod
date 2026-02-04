if isClient() then
    return
end

---@namespace HorseMod

local HorseManager = require("HorseMod/HorseManager")
local ContainerManager = require("HorseMod/attachments/ContainerManager")
local AttachmentManager = require("HorseMod/attachments/AttachmentManager")
local ManeManager = require("HorseMod/attachments/ManeManager")
local HorseUtils = require("HorseMod/Utils")


---@class AttachmentsSystem : System
local AttachmentsSystem = {}
AttachmentsSystem.__index = AttachmentsSystem

function AttachmentsSystem:update(horses, delta)
    for i = 1, #horses do
        local horse = horses[i]
        ContainerManager.track(horse)
    end
end

---Handle horse death.
---@param character IsoGameCharacter
AttachmentsSystem.onCharacterDeath = function(character)
    if not character:isAnimal() or not HorseUtils.isHorse(character) then
        return
    end
    ---@cast character IsoAnimal

    ManeManager.removeManes(character)
    AttachmentManager.unequipAllAttachments(character)
end

Events.OnCharacterDeath.Add(AttachmentsSystem.onCharacterDeath)

HorseManager.systems[#HorseManager.systems + 1] = AttachmentsSystem
