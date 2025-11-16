local HorseUtils = require("HorseMod/Utils")
local HorseManager = require("HorseMod/HorseManager")
local AttachmentUtils = require("HorseMod/horse/attachments/AttachmentUtils")
local HorseAttachmentSaddlebags = require("HorseMod/horse/attachments/AttachmentSaddlebags")
local HorseAttachmentGear = require("HorseMod/horse/attachments/AttachmentGear")
local HorseAttachmentManes = require("HorseMod/horse/attachments/AttachmentManes")


---@class HorseAttachmentReapply
local HorseAttachmentReapply = {}


local REAPPLY_RADIUS = 20
local reapplyTick = 0


---@param animal IsoAnimal
local function reapplyFor(animal)
    if not HorseUtils.isHorse(animal) then
        return
    end
    local bySlot, ground = AttachmentUtils.ensureHorseModData(animal)
    if not bySlot then
        return
    end

    local inv = animal:getInventory()

    for slot, fullType in pairs(bySlot) do
        if fullType and fullType ~= "" then
            local cur = AttachmentUtils.getAttachedItem(animal, slot)
            if cur and cur:getFullType() == fullType then
                AttachmentUtils.setAttachedItem(animal, slot, cur)
            else
                local found = inv:FindAndReturn(fullType)
                if found then
                    AttachmentUtils.setAttachedItem(animal, slot, found)
                    ground[slot] = nil
                else
                    local g = ground[slot]
                    if g and g.x and g.y and g.z then
                        local wo, sq = AttachmentUtils.findWorldItemOnSquare(g.x, g.y, g.z, fullType, g.id)
                        if wo then
                            local picked = AttachmentUtils.takeWorldItemToInventory(wo, sq, inv)
                            if picked then
                                AttachmentUtils.setAttachedItem(animal, slot, picked)
                                ground[slot] = nil
                            end
                        end
                    end

                    if not AttachmentUtils.getAttachedItem(animal, slot) then
                        if fullType ~= HorseAttachmentSaddlebags.SADDLEBAG_CONTAINER_TYPE then
                            inv:AddItem(fullType)
                            local fetched = inv:FindAndReturn(fullType)
                            if fetched then
                                AttachmentUtils.setAttachedItem(animal, slot, fetched)
                            end
                        end
                    end
                end
            end
            if slot == HorseAttachmentSaddlebags.SADDLEBAG_SLOT then
                if fullType == HorseAttachmentSaddlebags.SADDLEBAG_FULLTYPE then
                    HorseAttachmentSaddlebags.ensureSaddlebagContainer(animal, nil)
                else
                    HorseAttachmentSaddlebags.removeSaddlebagContainer(nil, animal)
                end
            end
        end
    end
    if not bySlot[HorseAttachmentSaddlebags.SADDLEBAG_SLOT] then
        HorseAttachmentSaddlebags.removeSaddlebagContainer(nil, animal)
    end
end

HorseAttachmentReapply.reapplyFor = reapplyFor


Events.OnTick.Add(function()
    reapplyTick = reapplyTick + 1
    if reapplyTick % 120 ~= 0 then
        return
    end

    local player = getPlayer()
    if not player then
        return
    end

    local cell = getCell()
    local z    = player:getZ()
    local px   = math.floor(player:getX())
    local py   = math.floor(player:getY())

    for x = px - REAPPLY_RADIUS, px + REAPPLY_RADIUS do
        for y = py - REAPPLY_RADIUS, py + REAPPLY_RADIUS do
            local sq = cell:getGridSquare(x, y, z)
            if sq then
                local animals = sq:getAnimals()
                if animals then
                    for i = 0, animals:size() - 1 do
                        local a = animals:get(i)
                        if HorseUtils.isHorse(a) then
                            if a:isDead() then
                                local md = a:getModData()
                                local already = md and md.HM_Attach and md.HM_Attach.DroppedOnDeath
                                if not already then
                                    HorseAttachmentGear.dropHorseGearOnDeath(a)
                                end
                            elseif a:isOnScreen() then
                                reapplyFor(a)
                                HorseAttachmentManes.ensureManesPresentAndColored(a)
                            end
                        end
                    end
                end
            end
        end
    end
end)


---@param character IsoGameCharacter
local function onCharacterDeath(character)
    if not character:isAnimal() or not HorseUtils.isHorse(character) then
        return
    end
    ---@cast character IsoAnimal

    HorseAttachmentGear.dropHorseGearOnDeath(character)
end

Events.OnCharacterDeath.Add(onCharacterDeath)


---@type IsoAnimal[]
local pendingHorses = {}

local function addAttachmentsToHorses()
    for i = #pendingHorses, 1, -1 do
        local horse = pendingHorses[i]
        if horse:isOnScreen() then
            table.remove(pendingHorses, i)
            reapplyFor(horse)
            HorseAttachmentManes.ensureManesPresentAndColored(horse)
        end
    end
end

Events.OnTick.Add(addAttachmentsToHorses)


HorseManager.onHorseAdded:add(function(horse)
    pendingHorses[#pendingHorses + 1] = horse
end)


HorseManager.onHorseRemoved:add(function(horse)
    for i = 1, #pendingHorses do
        if pendingHorses[i] == horse then
            table.remove(pendingHorses, i)
            break
        end
    end
end)

return HorseAttachmentReapply
