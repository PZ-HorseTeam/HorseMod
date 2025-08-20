require "TimedActions/ISPathFindAction"
local ISLeadHorse = require("HorseMod/ISLeadHorse")

local HorseRiding = {}
HorseRiding.playerMounts = {}

local function pid(p) return p and p:getPlayerNum() or -1 end

function HorseRiding.isMountableHorse(animal)
    if not animal or not animal.getAnimalType then return false end
    local t = animal:getAnimalType()
    return t == "stallion" or t == "mare"
end

function HorseRiding.canMountHorse(player, horse)
    if not player or not horse then return false end
    if HorseRiding.playerMounts[pid(player)] then return false end
    return HorseRiding.isMountableHorse(horse)
end

function HorseRiding.mountHorse(player, horse)
    if not HorseRiding.canMountHorse(player, horse) then return end

    -- Freeze horse and remember direction
    if horse.getPathFindBehavior2 then horse:getPathFindBehavior2():reset() end
    if horse.getBehavior then horse:getBehavior():setBlockMovement(true) end
    if horse.stopAllMovementNow then horse:stopAllMovementNow() end
    local lockDir = horse:getDir()

    -- Keep horse direction locked while walking to
    local function lockTick()
        if horse and horse:isExistInTheWorld() then horse:setDir(lockDir) end
    end
    Events.OnTick.Add(lockTick)

    -- Path player to the center of the horse to line up animation
    local hx, hy, hz = horse:getX(), horse:getY(), horse:getZ()
    local path = ISPathFindAction:pathToLocationF(player, hx, hy, hz)

    -- If path fails, just unfreeze and bail
    path:setOnFail(function()
        Events.OnTick.Remove(lockTick)
        if horse.getBehavior then horse:getBehavior():setBlockMovement(false) end
    end)

    -- On success: face direction of the horse, then queue the mount timed action
    path:setOnComplete(function()
        Events.OnTick.Remove(lockTick)

        -- face the same direction as the horse (better for animation sync)
        player:setDir(lockDir)

        -- Start the mount
        local action = ISLeadHorse:new(player, horse)

        action.onMounted = function()
            HorseRiding.playerMounts[player:getPlayerNum()] = horse
        end

        action.onCanceled = function()
            if horse.getBehavior then horse:getBehavior():setBlockMovement(false) end
            player:setVariable("RidingHorse", false)
            player:setVariable("MountingHorse", false)
        end

        ISTimedActionQueue.add(action)
    end)

    ISTimedActionQueue.add(path)
end

function HorseRiding.getMountedHorse(player)
    return HorseRiding.playerMounts[pid(player)]
end

function HorseRiding.dismountHorse(player)
    local id = player:getPlayerNum()
    local horse = HorseRiding.playerMounts[id]
    if not horse then return end

    if player.getAttachedAnimals then player:getAttachedAnimals():remove(horse) end
    if horse.getData then horse:getData():setAttachedPlayer(nil) end
    if horse.getBehavior then horse:getBehavior():setBlockMovement(false) end
    if horse.getPathFindBehavior2 then horse:getPathFindBehavior2():reset() end

    if horse.setVariable then
        horse:setVariable("bPathfind", false)
        horse:setVariable("animalWalking", false)
        horse:setVariable("animalRunning", false)
        horse:setVariable("HorseTrot", false)
        player:setVariable("HorseTrot", false)
    end

    if horse.stopAllMovementNow then horse:stopAllMovementNow() end
    if horse.getPathFindBehavior2 then horse:getPathFindBehavior2():reset() end

    if HorseRiding._clearRideCache then HorseRiding._clearRideCache(player:getPlayerNum()) end

    player:setVariable("RidingHorse", false)
    player:setVariable("MountingHorse", false)
    HorseRiding.playerMounts[id] = nil
end

local function toggleTrot(key)
    if key ~= Keyboard.KEY_C then return end
    local player = getSpecificPlayer(0)
    local horse = HorseRiding.getMountedHorse and HorseRiding.getMountedHorse(player)
    local riding = player:getVariableBoolean("RidingHorse")
    if horse and riding then
        local cur = horse:getVariableBoolean("HorseTrot")
        horse:setVariable("HorseTrot", not cur)
        player:setVariable("HorseTrot", not cur)
    end
end

Events.OnKeyPressed.Add(toggleTrot)

Events.OnContextKey.Add(function()
    local player = getSpecificPlayer(0)
    if player and HorseRiding.getMountedHorse(player) then
        HorseRiding.dismountHorse(player)
    end
end)

return HorseRiding
