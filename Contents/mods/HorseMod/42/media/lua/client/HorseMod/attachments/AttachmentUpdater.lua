---@namespace HorseMod

---REQUIREMENTS
local Attachments = require("HorseMod/attachments/Attachments")
local AttachmentData = require("HorseMod/attachments/AttachmentData")
local HorseManager = require("HorseMod/HorseManager")
local HorseUtils = require("HorseMod/Utils")
local ManeManager = require("HorseMod/attachments/ManeManager")
local ContainerManager = require("HorseMod/attachments/ContainerManager")

local AttachmentUpdater = {
    DEBUG_AttachmentUpdater = true,

    ---Holds currently already reapplied horses.
    ---@type table<IsoAnimal, true?>
    IS_REAPPLIED = {},
}
local IS_REAPPLIED = AttachmentUpdater.IS_REAPPLIED

---Reapply attachments to the `horse`.
---@param horse IsoAnimal
AttachmentUpdater.reapplyFor = function(horse)
    local inv = horse:getInventory()
    local modData = HorseUtils.getModData(horse)
    local bySlot = modData.bySlot

    for slot, fullType in pairs(bySlot) do
        -- try to retrieve the item from attached items, else create a fresh one
        local item = Attachments.getAttachedItem(horse, slot)
        if not item then
            item = inv:AddItem(fullType)
        end

        -- setup mane color
        if AttachmentData.MANE_SLOTS_SET[slot] then
            ManeManager.setupMane(horse, item, slot, modData)
        end

        Attachments.setAttachedItem(horse, slot, item)
    end

    -- set horse as reapplied
    IS_REAPPLIED[horse] = true
end







---@TODO set to update rate 8 for performance reasons
-- local UPDATE_RATE = 8
local UPDATE_RATE = 10
local TICK_AMOUNT = 0

---Verify that the horse doesn't need to get its attachments reapplied, and if yes
---then reapply those and set the horse status for updates.
---@param horses IsoAnimal[]
---@param delta number
function AttachmentUpdater:update(horses, delta)
    -- check UPDATE_RATE-th horses per tick
    local size = #horses
    local update_rate = math.min(UPDATE_RATE,size)
    if update_rate == 0 then return end

    TICK_AMOUNT = TICK_AMOUNT < update_rate and TICK_AMOUNT + 1 or 1

    for i = TICK_AMOUNT, size, update_rate do
        local horse = horses[i] --[[@as IsoAnimal]]
        ContainerManager.track(horse)

        -- if horse model is visible, set it as needing an update if not already reapplied
        local status = IS_REAPPLIED[horse]
        if horse:getModel() then
            if not status then
                AttachmentUpdater.reapplyFor(horse)
            end

        -- else set horse as needing to be reapplied until it's visible again
        else
            if status then
                IS_REAPPLIED[horse] = nil
            end
        end
    end
end


---Handle horse death.
---@param character IsoGameCharacter
AttachmentUpdater.onCharacterDeath = function(character)
    if not character:isAnimal() or not HorseUtils.isHorse(character) then
        return
    end
    ---@cast character IsoAnimal

    ManeManager.removeManes(character)
    Attachments.unequipAllAttachments(character)
    -- HorseAttachmentGear.dropHorseGearOnDeath(character)
end

Events.OnCharacterDeath.Add(AttachmentUpdater.onCharacterDeath)





---@TODO remove/comment for proper release, this is used to hot reload in-game for testing
for i, system in ipairs(HorseManager.systems) do
    ---@diagnostic disable-next-line
    if system.DEBUG_AttachmentUpdater then
        table.remove(HorseManager.systems,i)
    end
end

---Add system for horses
table.insert(HorseManager.systems, AttachmentUpdater)






return AttachmentUpdater