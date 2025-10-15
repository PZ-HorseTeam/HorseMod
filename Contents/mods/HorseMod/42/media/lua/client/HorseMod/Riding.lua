require("TimedActions/ISPathFindAction")

local MountHorseAction = require("HorseMod/player/MountHorseAction")
local DismountHorseAction = require("HorseMod/player/DismountHorseAction")
local HorseUtils = require("HorseMod/Utils")


---@class MountPair
---@field rider IsoPlayer
---@field mount IsoAnimal
local MountPair = {}
MountPair.__index = MountPair


---@param key string
---@param value number | boolean
function MountPair:setAnimationVariable(key, value)
    self.rider:setVariable(key, value)
    self.mount:setVariable(key, value)
end


-- TODO: how much of this is even needed??

function MountPair:breakPair()
    self:setAnimationVariable("RidingHorse", false)
    self:setAnimationVariable("HorseTrot", false)

    local attached = self.rider:getAttachedAnimals()
    attached:remove(self.mount)
    self.mount:getData():setAttachedPlayer(nil)

    self.mount:getBehavior():setBlockMovement(false)
    self.mount:getPathFindBehavior2():reset()

    self.rider:setVariable("HorseTrot", false)
    self.rider:setAllowRun(true)
    self.rider:setAllowSprint(true)
    self.rider:setTurnDelta(1)
    self.rider:setSneaking(false)

    self.mount:setVariable("bPathfind", false)
    self.mount:setVariable("animalWalking", false)
    self.mount:setVariable("animalRunning", false)

    self.rider:setVariable("MountingHorse", false)
    self.rider:setVariable("isTurningLeft", false)
    self.rider:setVariable("isTurningRight", false)
end


function MountPair:make()
    self.rider:getAttachedAnimals():add(self.mount)
    self.mount:getData():setAttachedPlayer(self.rider)

    self:setAnimationVariable("RidingHorse", true)
    self:setAnimationVariable("HorseTrot", false)
    self.rider:setAllowRun(false)
    self.rider:setAllowSprint(false)

    self.rider:setTurnDelta(0.65)

    self.rider:setVariable("isTurningLeft", false)
    self.rider:setVariable("isTurningRight", false)

    local geneSpeed = self.mount:getUsedGene("speed"):getCurrentValue()
    self.rider:setVariable("geneSpeed", geneSpeed)

    self.mount:getPathFindBehavior2():reset()
    self.mount:getBehavior():setBlockMovement(true)
    self.mount:stopAllMovementNow()

    self.mount:setVariable("bPathfind", false)
    self.mount:setVariable("animalWalking", false)
    self.mount:setVariable("animalRunning", false)

    -- TODO: are these even needed
    self.mount:setWild(false)
    self.mount:setVariable("isHorse", true)
end


---@param rider IsoPlayer
---@param mount IsoAnimal
---@return self
---@nodiscard
function MountPair.new(rider, mount)
    return setmetatable(
        {
            rider = rider,
            mount = mount
        },
        MountPair
    )
end


---@param p IsoPlayer
---@return integer
---@nodiscard
local function pid(p)
    return p and p:getPlayerNum() or -1
end


local HorseRiding = {}

---@type {[integer]: MountPair | nil}
HorseRiding.playerMounts = {}


---@param animal IsoAnimal
---@return boolean
---@nodiscard
function HorseRiding.isMountableHorse(animal)
    local type = animal:getAnimalType()
    return type == "stallion" or type == "mare"
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
    local pairing = HorseRiding.playerMounts[pid(player)]
    if not pairing then
        return nil
    end

    return pairing.mount
end


---@param rider IsoPlayer
---@return MountPair | nil
---@nodiscard
function HorseRiding.getMountPair(rider)
    return HorseRiding.playerMounts[pid(rider)]
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

    local saddle = HorseUtils.getSaddle(horse)

    local pairing = MountPair.new(player, horse)

    path:setOnComplete(function()
        cleanup()
        player:setDir(lockDir)
        local action = MountHorseAction:new(pairing, side, saddle)

        action.onMounted = function()
            HorseRiding.playerMounts[pid(player)] = pairing
            Events.OnTick.Remove(lockTick)
        end
        ISTimedActionQueue.add(action)
    end)
    ISTimedActionQueue.add(path)
end


---@param player IsoPlayer
function HorseRiding.dismountHorse(player)
    local id = player:getPlayerNum()
    local pair = HorseRiding.getMountPair(player)
    if not pair then
        return
    end

    local horse = pair.mount

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
        local sq = getSquare(nx, ny, nz)
        if not sq then
            return true
        end
        if sq:isSolid() or sq:isSolidTrans() then
            return true
        end
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

    local saddleItem = HorseUtils.getSaddle(horse)

    player:setDir(lockDir)

    local action = DismountHorseAction:new(
        pair,
        player,
        side,
        saddleItem,
        tx,
        ty,
        tz
    )

    action.onComplete = function()
        HorseRiding._clearRideCache(player:getPlayerNum())
        HorseRiding.playerMounts[id] = nil
    end

    ISTimedActionQueue.add(action)
end


---@param key integer
local function toggleTrot(key)
    if key ~= Keyboard.KEY_X then return end

    local player = getSpecificPlayer(0)
    local mountPair = HorseRiding.getMountPair(player)
    if mountPair and player:getVariableBoolean("RidingHorse") then
        local current = mountPair.mount:getVariableBoolean("HorseTrot")

        mountPair:setAnimationVariable("HorseTrot", not current)

        -- TODO: why is this this way? are the values supposed to be different?
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
    local mountPair = HorseRiding.getMountPair(player)
    if mountPair and player:getVariableBoolean("RidingHorse") and mountPair.mount:getVariableBoolean("HorseGallop") then
        mountPair:setAnimationVariable("HorseJump", true)
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

Events.OnGameStart.Add(initHorseMod)


return HorseRiding