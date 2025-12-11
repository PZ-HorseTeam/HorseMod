local HorseRiding = require("HorseMod/Riding")
local HorseUtils = require("HorseMod/Utils")
local MountPair = require("HorseMod/MountPair")


---@param player IsoPlayer
---@return IsoAnimal | nil
local function findHorseOnPlayerSquare(player)
    local square = player:getSquare()
    if not square then
        return nil
    end

    local cell = getCell()
    if not cell then
        return nil
    end

    if square then
        local animals = square:getAnimals()
        if animals then
            for i = 0, animals:size() - 1 do
                local animal = animals:get(i)
                if HorseUtils.isHorse(animal) then
                    return animal
                end
            end
        end
    end

    return nil
end


local function tryRemountPlayer()
    local player = getSpecificPlayer(0)
    local modData = player:getModData()
    if not modData.ShouldRemount then
        Events.OnTick.Remove(tryRemountPlayer)
    end
    if HorseRiding.getMount(player) then
        Events.OnTick.Remove(tryRemountPlayer)
    end

    if player:getSquare() == nil then
        return
    end

    local horse = findHorseOnPlayerSquare(player)
    if horse and horse:isExistInTheWorld() then
        local pair = MountPair.new(player, horse)
        pair:setDirection(horse:getDir())

        HorseRiding.createMountFromPair(pair)
        Events.OnTick.Remove(tryRemountPlayer)
    end
end

Events.OnTick.Add(tryRemountPlayer)