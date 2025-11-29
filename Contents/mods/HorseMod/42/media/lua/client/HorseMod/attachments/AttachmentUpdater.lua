---@namespace HorseMod

---REQUIREMENTS
local Attachments = require("HorseMod/Attachments")
local AttachmentData = require("HorseMod/AttachmentData")
local HorseManager = require("HorseMod/HorseManager")
local HorseUtils = require("HorseMod/Utils")
local ManeManager = require("HorseMod/attachments/ManeManager")

---@class AttachmentUpdater
---@field PENDING_HORSES IsoAnimal[]
---@field IS_REAPPLIED table<IsoAnimal, true?>
local AttachmentUpdater = {
    DEBUG_AttachmentUpdater = true,
    PENDING_HORSES = {},
    IS_REAPPLIED = {},
}
local PENDING_HORSES = AttachmentUpdater.PENDING_HORSES
local IS_REAPPLIED = AttachmentUpdater.IS_REAPPLIED

---Reapply attachments to the `horse`.
---@param horse IsoAnimal
AttachmentUpdater.reapplyFor = function(horse)
    DebugLog.log("reapply: "..horse:getFullName())
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
end







---@TODO set to update rate 8 for performance reasons
-- local UPDATE_RATE = 8
local UPDATE_RATE = 1
local TICK_AMOUNT = 0

---Verify that the horse doesn't need to get its attachments reapplied, and if yes
---then reapply those and set the horse status for updates.
---@param horses IsoAnimal[]
---@param delta number
function AttachmentUpdater:update(horses, delta)
    -- DebugLog.log(tostring(ticks))
    -- apply attachments to new horses
    for i = #PENDING_HORSES, 1, -1 do
        local horse = PENDING_HORSES[i]
        if horse:isOnScreen() then
            table.remove(PENDING_HORSES, i)
            AttachmentUpdater.reapplyFor(horse)
            -- HorseAttachmentManes.ensureManesPresentAndColored(horse)

            -- set as done
            IS_REAPPLIED[horse] = true
        end
    end

    -- check UPDATE_RATE-th horses per tick
    local size = #horses
    local update_rate = math.min(UPDATE_RATE,size)
    if update_rate == 0 then return end

    TICK_AMOUNT = TICK_AMOUNT < update_rate and TICK_AMOUNT + 1 or 1

    for i = TICK_AMOUNT, size, update_rate do
        local horse = horses[i] --[[@as IsoAnimal]]

        -- if horse is visible, set it as needing an update if not already reapplied
        local status = IS_REAPPLIED[horse]
        horse:addLineChatElement(tostring(status))
        if horse:isOnScreen() then
            if not status then
                DebugLog.log("set for reapply: "..tostring(horse:getFullName()))
                
                -- update reapply status
                table.insert(PENDING_HORSES, horse)
            end

        -- else set horse as needing to be checked until it goes back in the screen
        else
            if status then
                DebugLog.log("reset for reapply: "..tostring(horse:getFullName()))
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
    if system.DEBUG_AttachmentUpdater then
        table.remove(HorseManager.systems,i)
    end
end

--- Hook to OnTick for horses
table.insert(HorseManager.systems, AttachmentUpdater)

---@param horse IsoAnimal
HorseManager.onHorseAdded:add(function(horse)
    DebugLog.log("onHorseAdded: "..horse:getFullName())
    PENDING_HORSES[#PENDING_HORSES + 1] = horse
end)


---@param horse IsoAnimal
HorseManager.onHorseRemoved:add(function(horse)
    DebugLog.log("onHorseRemoved: "..horse:getFullName())
    for i = #PENDING_HORSES, 1, -1 do
        if PENDING_HORSES[i] == horse then
            IS_REAPPLIED[horse] = nil
            table.remove(PENDING_HORSES, i)
            DebugLog.log("    remove horse from pending")
            break
        end
    end
end)


return AttachmentUpdater