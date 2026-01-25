if isClient() then
    -- this only works in SP anyway
    return
end

local MountPair = require("HorseMod/MountPair")
local MountingUtility = require("HorseMod/mounting/MountingUtility")
local Mounts = require("HorseMod/Mounts")
local HorseUtils = require("HorseMod/Utils")


---@param square IsoGridSquare
---@param id integer
---@return IsoAnimal?
---@nodiscard
local function findAnimalOnSquare(square, id)
    local animals = square:getAnimals()
    for i = 0, animals:size() - 1 do
        local animal = animals:get(i)
        if animal:getAnimalID() == id then
            return animal
        end
    end

    return nil
end


---@param player IsoPlayer
local function tryRemountPlayer(player)
    local modData = player:getModData()
    if not modData.remountAnimal then
        print("[HORSE] no remountAnimal")
        return
    end

    local square = player:getSquare()
    if not square then
        print("[HORSE] no square")
        return
    end

    local animal = findAnimalOnSquare(square, modData.remountAnimal)
    if animal and MountingUtility.canMountHorse(player, animal) then
        local pair = MountPair.new(player, animal)
        pair:setDirection(animal:getDir())
        Mounts.addMount(pair.rider, pair.mount)
    end
end

---@param player IsoPlayer
local function scheduleRemount(_, player)
    -- hack: 0 second delay means run next tick
    --  needed because this event triggers before the player is actually placed in the world
    HorseUtils.runAfter(0, tryRemountPlayer, player)
end

Events.OnCreatePlayer.Add(scheduleRemount)
