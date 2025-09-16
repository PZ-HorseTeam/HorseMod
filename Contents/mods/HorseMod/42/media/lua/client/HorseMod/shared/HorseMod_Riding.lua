require "TimedActions/ISPathFindAction"
local ISLeadHorse = require("HorseMod/player/HorseMod_ISLeadHorse")
local ISDismountHorse = require("HorseMod/player/HorseMod_ISDismountHorse")
local Stamina = require("HorseMod/HorseMod_Stamina")
local HorseUtils = require("HorseMod/HorseMod_Utils")

local HorseRiding = {}
HorseRiding.playerMounts = {}
HorseRiding.lastMounted = {}

local function pid(p) return p and p:getPlayerNum() or -1 end-- Face the horse's center from the character's current position.

function HorseRiding.isMountableHorse(animal)
    -- print("Animal: ", animal, "| Type: ", animal.getAnimalType)
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
    local data = horse.getData and horse:getData()
    if data then
        -- Detach from tree
        local tree = data.getAttachedTree and data:getAttachedTree()
        if tree then
            sendAttachAnimalToTree(horse, player, tree, true)
            data:setAttachedTree(nil)
        end
        -- Detach from any leading player
        local leader = data.getAttachedPlayer and data:getAttachedPlayer()
        if leader and leader.getAttachedAnimals then
            leader:getAttachedAnimals():remove(horse)
            data:setAttachedPlayer(nil)
        end
    end

    -- Ensure the mounting player isn't leading the horse
    if player.removeAttachedAnimal then
        player:removeAttachedAnimal(horse)
    end

    -- Freeze horse and remember direction
    if horse.getPathFindBehavior2 then horse:getPathFindBehavior2():reset() end
    if horse.getBehavior then
        local behavior = horse:getBehavior()
        behavior:setBlockMovement(true)
        behavior:setDoingBehavior(false)
    end
    if horse.stopAllMovementNow then horse:stopAllMovementNow() end
    local lockDir = horse:getDir()

    -- Keep horse direction locked while walking to
    local function lockTick()
        if horse and horse:isExistInTheWorld() then horse:setDir(lockDir) end
    end
    Events.OnTick.Add(lockTick)

    local mountLeft  = horse:getAttachmentWorldPos("mountLeft")
    local mountRight = horse:getAttachmentWorldPos("mountRight")

    local mountPosX = mountRight:x()
    local mountPosY = mountRight:y()
    local mountPosZ = mountRight:z()
    local side = "right"
    if player:DistToSquared(mountLeft:x(), mountLeft:y()) <
       player:DistToSquared(mountRight:x(), mountRight:y()) then
        mountPosX = mountLeft:x()
        mountPosY = mountLeft:y()
        mountPosZ = mountLeft:z()
        side = "left"
    end

    local path = ISPathFindAction:pathToLocationF(player, mountPosX, mountPosY, mountPosZ)

    local function cleanup()
        Events.OnTick.Remove(lockTick)
        if horse.getBehavior then horse:getBehavior():setBlockMovement(false) end
    end

    path:setOnFail(cleanup)

    path.stop = function(self)
        cleanup()
        ISPathFindAction.stop(self)
    end

    local saddle = HorseUtils.horseHasSaddleItem(horse)

    path:setOnComplete(function()
        cleanup()
        player:setDir(lockDir)
        local action = ISLeadHorse:new(player, horse, side, saddle)

        action.onMounted = function()
            HorseRiding.playerMounts[player:getPlayerNum()] = horse
            HorseRiding.lastMounted[player:getPlayerNum()]  = horse
            player:setTurnDelta(0.8)
            Events.OnTick.Remove(lockTick)
        end

        action.onCanceled = function()
            if horse.getBehavior then horse:getBehavior():setBlockMovement(false) end
            horse:setVariable("RidingHorse", false)
            player:setVariable("RidingHorse", false)
            player:setVariable("MountingHorse", false)
            player:setVariable("isTurningLeft", false)
            player:setVariable("isTurningRight", false)
            player:setTurnDelta(1)
        end
        ISTimedActionQueue.add(action)
    end)
    ISTimedActionQueue.add(path)
end

function HorseRiding.getMountedHorse(player)
    return HorseRiding.playerMounts[pid(player)]
end

function HorseRiding.dismountHorse(player)
    local id    = player:getPlayerNum()
    local horse = HorseRiding.playerMounts[id]
    if not horse then return end

    if horse.getPathFindBehavior2 then horse:getPathFindBehavior2():reset() end
    if horse.getBehavior then
        local behavior = horse:getBehavior()
        behavior:setBlockMovement(true)
        behavior:setDoingBehavior(false)
    end
    if horse.stopAllMovementNow then horse:stopAllMovementNow() end
    local lockDir = horse:getDir()

    local lpos = horse:getAttachmentWorldPos("mountLeft")
    local rpos = horse:getAttachmentWorldPos("mountRight")
    local hx, hy = horse:getX(), horse:getY()

    local dl = (hx - lpos:x())^2 + (hy - lpos:y())^2
    local dr = (hx - rpos:x())^2 + (hy - rpos:y())^2
    local side, tx, ty, tz = "right", rpos:x(), rpos:y(), rpos:z()
    if dl < dr then side, tx, ty, tz = "left", lpos:x(), lpos:y(), lpos:z() end

    local function centerBlocked(nx, ny, nz)
        local sq = getCell():getGridSquare(math.floor(nx), math.floor(ny), nz or horse:getZ())
        if not sq then return true end
        if sq:isSolid() or sq:isSolidTrans() then return true end
        return false
    end
    if centerBlocked(tx, ty, tz) then
        local ox, oy, oz = (side=="right") and lpos:x() or rpos:x(), (side=="right") and lpos:y() or rpos:y(), (side=="right") and lpos:z() or rpos:z()
        if not centerBlocked(ox, oy, oz) then
            if side == "right" then side = "left" else side = "right" end
            tx, ty, tz = ox, oy, oz
        end
    end

    local saddleItem = HorseUtils.horseHasSaddleItem(horse)

    -- Start the timed action
    player:setDir(lockDir)

    -- Start the timed action
    local act = ISDismountHorse:new(player, horse, side, saddleItem, tx, ty, tz, 200)
    act.onComplete = function()
        if player.getAttachedAnimals then player:getAttachedAnimals():remove(horse) end
        if horse.getData then horse:getData():setAttachedPlayer(nil) end

        if HorseRiding._clearRideCache then HorseRiding._clearRideCache(player:getPlayerNum()) end
        player:faceThisObject(horse)

        player:setVariable("RidingHorse", false)
        player:setVariable("HorseTrot", false)
        player:setVariable("MountingHorse", false)
        player:setVariable("isTurningLeft", false)
        player:setVariable("isTurningRight", false)
        player:setAllowRun(true)
        player:setTurnDelta(1)
        player:setSneaking(false)

        HorseRiding.playerMounts[id] = nil
        HorseRiding.lastMounted[id] = horse
    end
    ISTimedActionQueue.add(act)
end

local function toggleTrot(key)
    if key ~= Keyboard.KEY_X then return end
    local player = getSpecificPlayer(0)
    local horse = HorseRiding.getMountedHorse and HorseRiding.getMountedHorse(player)
    local riding = player:getVariableBoolean("RidingHorse")
    if horse and riding then
        local cur = horse:getVariableBoolean("HorseTrot")
        horse:setVariable("HorseTrot", not cur)
        player:setVariable("HorseTrot", not cur)
        if cur == true then
            player:setTurnDelta(0.8)
        else
            player:setTurnDelta(0.8)
        end
    end
end

Events.OnKeyPressed.Add(toggleTrot)

local function horseJump(key)
    local options = PZAPI.ModOptions:getOptions("HorseMod")
    local jumpKey = Keyboard.KEY_SPACE
    if options then
        local opt = options:getOption("HorseJumpButton")
        if opt and opt.getValue then jumpKey = opt:getValue() end
    end
    if key ~= jumpKey then return end

    local player = getSpecificPlayer(0)
    local horse = HorseRiding.getMountedHorse and HorseRiding.getMountedHorse(player)
    if horse and player:getVariableBoolean("RidingHorse") and horse:getVariableBoolean("HorseGallop") then
        horse:setVariable("HorseJump", true)
        player:setVariable("HorseJump", true)
    end
end

Events.OnKeyPressed.Add(horseJump)

local function initHorseMod()
    local player = getPlayer()
    player:setVariable("RidingHorse", false)
    player:setVariable("MountingHorse", false)
    player:setVariable("DismountFinished", false)
    player:setVariable("MountFinished", false)
    if HorseRiding._clearRideCache then HorseRiding._clearRideCache(player:getPlayerNum()) end
end

Events.OnGameStart.Add(initHorseMod)

return HorseRiding
