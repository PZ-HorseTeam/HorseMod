local HorseRiding = require("HorseMod/HorseRiding")
require "TimedActions/ISPathFindAction"

local DEST_X = 10615
local DEST_Y = 9807

local lastHorse = {}

Events.OnPlayerUpdate.Add(function(player)
    if not player then return end
    local pid = player:getPlayerNum()
    local h = HorseRiding.getMountedHorse and HorseRiding.getMountedHorse(player)
    if h and h.isExistInTheWorld and h:isExistInTheWorld() then
        lastHorse[pid] = h
    end
end)

local function commandHorseTo(horse, tx, ty, tz)
    if not (horse and horse.isExistInTheWorld and horse:isExistInTheWorld()) then
        return
    end

    local z = tz or horse:getZ()

    if horse.getBehavior then horse:getBehavior():setBlockMovement(false) end
    if horse.stopAllMovementNow then horse:stopAllMovementNow() end
    if horse.getPathFindBehavior2 then horse:getPathFindBehavior2():reset() end

    local ad = horse.getData and horse:getData() or nil
    local attachedPlayer = ad and ad.getAttachedPlayer and ad:getAttachedPlayer() or nil
    if attachedPlayer and attachedPlayer.getAttachedAnimals and ad then
        attachedPlayer:getAttachedAnimals():remove(horse)
        ad:setAttachedPlayer(nil)
    end

    local pfb = horse.getPathFindBehavior2 and horse:getPathFindBehavior2() or nil
    local ok = false
    if pfb and pfb.pathToLocationF then
        pfb:pathToLocationF(tx + 0.5, ty + 0.5, z)
        ok = true
    elseif horse.pathToLocation then
        horse:pathToLocation(tx, ty, z)
        ok = true
    end

    if horse.setVariable then
        horse:setVariable("bPathfind", ok)
        horse:setVariable("animalWalking", true)
        horse:setVariable("animalRunning", false)
    end
end

Events.OnKeyPressed.Add(function(key)
    if key ~= Keyboard.KEY_G then return end

    local player = getSpecificPlayer(0)
    if not player then return end

    local horse = HorseRiding.getMountedHorse and HorseRiding.getMountedHorse(player)
    if not (horse and horse:isExistInTheWorld()) then
        horse = lastHorse[player:getPlayerNum()]
    end

    commandHorseTo(horse, DEST_X, DEST_Y, 0)
end)
