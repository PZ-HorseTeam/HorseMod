require("TimedActions/ISPathFindAction")

local ISMountHorse = require("HorseMod/player/ISMountHorse")
local ISDismountHorse = require("HorseMod/player/ISDismountHorse")
local HorseUtils = require("HorseMod/Utils")


local HorseRiding = {}

---@type {[integer]: IsoAnimal | nil}
HorseRiding.playerMounts = {}

---@type {[integer]: IsoAnimal | nil}
HorseRiding.lastMounted = {}


---@param animal IsoAnimal
---@return boolean
---@nodiscard
function HorseRiding.isMountableHorse(animal)
    if not animal then
        return false
    end

    local t = animal:getAnimalType()
    return t == "stallion" or t == "mare"
end


---@param player IsoPlayer
---@param horse IsoAnimal
---@return boolean
---@nodiscard
function HorseRiding.canMountHorse(player, horse)
    if HorseRiding.playerMounts[pid(player)] then
        return false
    end

    return HorseRiding.isMountableHorse(horse)
end


---@param player IsoPlayer
---@return IsoAnimal | nil
---@nodiscard
function HorseRiding.getMountedHorse(player)
    return HorseRiding.playerMounts[pid(player)]
end


-- TODO: mountHorse and dismountHorse are too long and have a lot of redundant code


---@param player IsoPlayer
---@param horse IsoAnimal
function HorseRiding.mountHorse(player, horse)
    if not HorseRiding.canMountHorse(player, horse) then return end

    local data = horse:getData()
    -- TODO: check if this nil check is actually necessary
    --  an animal's data *is* null by default,
    --  but it seems like it might always gets initialised when the animal spawns
    if data then
        -- Detach from tree
        local tree = data:getAttachedTree()
        if tree then
            sendAttachAnimalToTree(horse, player, tree, true)
            data:setAttachedTree(nil)
        end
        -- Detach from any leading player
        local leader = data:getAttachedPlayer()
        if leader then
            leader:getAttachedAnimals():remove(horse)
            data:setAttachedPlayer(nil)
        end
    end

    -- Ensure the mounting player isn't leading the horse
    player:removeAttachedAnimal(horse)

    -- Freeze horse and remember direction
    horse:getPathFindBehavior2():reset()

    local behavior = horse:getBehavior()
    behavior:setBlockMovement(true)
    behavior:setDoingBehavior(false)

    horse:stopAllMovementNow()
    local lockDir = horse:getDir()

    -- Keep horse direction locked while walking to
    local function lockTick()
        if horse:isExistInTheWorld() then horse:setDir(lockDir) end
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
        horse:getBehavior():setBlockMovement(false)
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
        local action = ISMountHorse:new(player, horse, side, saddle)

        action.onMounted = function()
            HorseRiding.playerMounts[player:getPlayerNum()] = horse
            HorseRiding.lastMounted[player:getPlayerNum()]  = horse
            player:setTurnDelta(0.65)
            Events.OnTick.Remove(lockTick)
        end

        action.onCanceled = function()
            horse:getBehavior():setBlockMovement(false)
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


---@param player IsoPlayer
function HorseRiding.dismountHorse(player)
    local id = player:getPlayerNum()
    local horse = HorseRiding.playerMounts[id]
    if not horse then return end

    horse:getPathFindBehavior2():reset()

    local behavior = horse:getBehavior()
    behavior:setBlockMovement(true)
    behavior:setDoingBehavior(false)

    horse:stopAllMovementNow()
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
        local ox = (side=="right") and lpos:x() or rpos:x()
        local oy = (side=="right") and lpos:y() or rpos:y()
        local oz = (side=="right") and lpos:z() or rpos:z()
        if not centerBlocked(ox, oy, oz) then
            if side == "right" then
                side = "left"
            else
                side = "right"
            end
            tx, ty, tz = ox, oy, oz
        end
    end

    local saddleItem = HorseUtils.horseHasSaddleItem(horse)

    player:setDir(lockDir)

    local action = ISDismountHorse:new(
        player,
        horse,
        side,
        saddleItem,
        tx,
        ty,
        tz,
        200
    )

    action.onComplete = function()
        HorseRiding._clearRideCache(player:getPlayerNum())
        HorseRiding.playerMounts[id] = nil
        HorseRiding.lastMounted[id] = horse
    end

    ISTimedActionQueue.add(action)
end


---@param key integer
local function toggleTrot(key)
    if key ~= Keyboard.KEY_X then return end

    local player = getSpecificPlayer(0)
    local horse = HorseRiding.getMountedHorse(player)
    if horse and player:getVariableBoolean("RidingHorse") then
        local current = horse:getVariableBoolean("HorseTrot")

        horse:setVariable("HorseTrot", not current)
        player:setVariable("HorseTrot", not current)

        if current == true then
            player:setTurnDelta(0.65)
        else
            player:setTurnDelta(0.65)
        end
    end
end

Events.OnKeyPressed.Add(toggleTrot)


---@param key integer
local function horseJump(key)
    local options = PZAPI.ModOptions:getOptions("HorseMod")
    local jumpKey = Keyboard.KEY_SPACE

    if options then
        -- TODO: move mod options to a module
        local opt = options:getOption("HorseJumpButton")
        assert(opt ~= nil and opt.type == "keybind")
        ---@cast opt umbrella.ModOptions.Keybind
        jumpKey = opt:getValue()
    end

    if key ~= jumpKey then return end

    local player = getSpecificPlayer(0)
    local horse = HorseRiding.getMountedHorse(player)
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
    HorseRiding._clearRideCache(player:getPlayerNum())
end

Events.OnCreatePlayer.Add(initHorseMod)


return HorseRiding