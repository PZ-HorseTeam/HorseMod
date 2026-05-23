local mountcommands = require("HorseMod/networking/mountcommands")
local soundcommands = require("HorseMod/networking/soundcommands")
local commands = require("HorseMod/networking/commands")
local Event = require("HorseMod/Event")
local AnimationVariable = require("HorseMod/definitions/AnimationVariable")
local MountedAnimationState = require("HorseMod/riding/MountedAnimationState")
local MountedDirection = require("HorseMod/riding/MountedDirection")

local IS_CLIENT = isClient()
local IS_SERVER = isServer()


---@param text string
---@param ... any
local function log(text, ...)
    DebugLog.log("[HorseMod] [Mounts] " .. string.format(text, ...))
end


local TEMP_VECTOR2 = Vector2.new()

---@type table<IsoPlayer, integer>
local playerMountMap = {}

---@type table<integer, IsoPlayer>
local mountPlayerMap = {}

---@type table<integer, integer>
local mountedAnimalLockTicks = {}

---@type table<IsoPlayer, integer>
local lastDismountTimestamps = {}

local Mounts = {}


---Triggered when a player mounts a horse.
Mounts.onMount = Event.new--[[@<IsoPlayer, IsoAnimal>]]()

---Triggered when a player dismounts a horse.
Mounts.onDismount = Event.new--[[@<IsoPlayer, IsoAnimal>]]()


---@readonly
local LOCK_REFRESH_TICKS = 6000

---@param animal IsoAnimal
local function refreshMountedAnimalBlock(animal)
    animal:getBehavior():setBlockMovement(true)
    mountedAnimalLockTicks[commands.getAnimalId(animal)] = 0
end

---@param player IsoPlayer
local function setMountedPlayerLock(player)
    if not player:getIgnoreMovement() then
        player:setIgnoreMovement(true)
    end

    if not player:isIgnoreInputsForDirection() then
        player:setIgnoreInputsForDirection(true)
    end

    if not player:isIgnoringAimingInput() then
        player:setIgnoreAimingInput(true)
    end

    player:setAllowRun(false)
    player:setAllowSprint(false)
    player:setSneaking(false)
    player:setIgnoreAutoVault(true)
end

---@param player IsoPlayer
---@param animal IsoAnimal
local function syncMountedPlayerToAnimal(player, animal)
    player:setForceX(animal:getX())
    player:setForceY(animal:getY())
    player:setZ(animal:getZ())
    -- Pin the rider to the horse's smoothed visual angle, not a cardinal IsoDirections snap
    local direction = MountedDirection.toRiderDirection(animal:getDir())
    local angle = MountedDirection.getMovementAngle(animal, direction)
    TEMP_VECTOR2:setLengthAndDirection(angle, 1.0)
    player:setTargetAndCurrentDirection(TEMP_VECTOR2:getX(), TEMP_VECTOR2:getY())
end

---@param animal IsoAnimal
local function setMountedAnimalLock(animal)
    -- Per-tick: only refresh the block-movement timeout
    local animalId = commands.getAnimalId(animal)
    local ticks = mountedAnimalLockTicks[animalId]
    if not ticks then
        ticks = 0
    end

    ticks = ticks + 1
    if ticks >= LOCK_REFRESH_TICKS then
        refreshMountedAnimalBlock(animal)
    else
        mountedAnimalLockTicks[animalId] = ticks
    end
end

---Suppress vanilla state flipping while mounted near zombies
---@param animal IsoAnimal
local function suppressMountedAnimalAI(animal)
    if animal:isAlerted() then
        animal:setIsAlerted(false)
    end

    local idleState = animal:getDefaultState()
    if not animal:isCurrentState(idleState) then
        animal:changeState(idleState)
    end

    animal:setVariable("bMoving", false)
    animal:setVariable("bPathfind", false)
end

---@param animal IsoAnimal
local function lockMountedAnimal(animal)
    refreshMountedAnimalBlock(animal)
    animal:getPathFindBehavior2():reset()
    animal:setPath2(nil)
    animal:setMoving(false)
    animal:setVariable("bPathfind", false)
    animal:setDeferredMovementEnabled(false)
    animal:setVariable("animalWalking", false)
    animal:setVariable("animalRunning", false)
    animal:setIsAlerted(false)
    local idleState = animal:getDefaultState()
    if not animal:isCurrentState(idleState) then
        animal:changeState(idleState)
    end
end

---@param animal IsoAnimal
local function unlockMountedAnimal(animal)
    animal:getPathFindBehavior2():reset()
    animal:setPath2(nil)
    animal:setMoving(false)
    animal:setVariable("bPathfind", false)
    animal:setVariable("animalWalking", false)
    animal:setVariable("animalRunning", false)
    animal:setDeferredMovementEnabled(true)
    animal:getBehavior():setBlockMovement(false)
end

---@param player IsoPlayer
---@param id integer
local function addMountID(player, id)
    local oldMount = playerMountMap[player]
    if oldMount then
        if oldMount == id then
            return
        end
        Mounts.removeMount(player)
    end

    playerMountMap[player] = id
    mountPlayerMap[id] = player
end

---@param player IsoPlayer
---@param animal IsoAnimal
function Mounts.addMount(player, animal)
    local oldMount = Mounts.getMount(player)
    if oldMount then
        if oldMount == animal then
            return
        end
        Mounts.removeMount(player)
    end

    addMountID(player, commands.getAnimalId(animal))

    setMountedPlayerLock(player)
    lockMountedAnimal(animal)
    animal:setVariable(AnimationVariable.RIDING_HORSE, true)
    player:setVariable(AnimationVariable.RIDING_HORSE, true)
    player:setVariable(AnimationVariable.TROT, false)
    MountedAnimationState.setSpeedVariables(player, animal)
    MountedAnimationState.setMovementVariables(player, animal, false, false)
    MountedAnimationState.setTurnVariables(player, animal, 0)
    MountedAnimationState.setReinsVariable(player, false)
    MountedDirection.set(player, animal, player:getDir())

    if IS_SERVER then
        mountcommands.Mount:send(
            nil,
            {
                animal = commands.getAnimalId(animal),
                character = commands.getPlayerId(player),
            }
        )
        -- broadcast the snort so remote clients hear the same
        -- audio cue the local rider hears when mounting
        soundcommands.HorseSoundOneShot:send(nil--[[@as IsoPlayer?]], {
            animal = commands.getAnimalId(animal),
            sound = "HorseMountSnort",
        })
    end

    Mounts.onMount:trigger(player, animal)
end

---@param player IsoPlayer
local function removeMountID(player)
    local id = playerMountMap[player]
    playerMountMap[player] = nil
    mountPlayerMap[id] = nil
    mountedAnimalLockTicks[id] = nil
end

---@param player IsoPlayer
function Mounts.removeMount(player)
    if not Mounts.hasMount(player) then
        return
    end

    local mountId = playerMountMap[player]
    removeMountID(player)
    lastDismountTimestamps[player] = getTimestampMs()

    player:setVariable(AnimationVariable.RIDING_HORSE, false)
    player:setVariable(AnimationVariable.TROT, false)
    player:setVariable(AnimationVariable.GALLOP, false)
    player:setVariable(AnimationVariable.JUMP, false)
    player:setVariable(AnimationVariable.HAS_REINS, false)
    player:setVariable("animalWalking", false)
    player:setVariable("animalRunning", false)
    player:setVariable("HorseGalloping", false)
    player:setVariable("walkstateRun", false)
    player:setVariable("isTurningLeft", false)
    player:setVariable("isTurningRight", false)
    player:setVariable("isTurning", false)
    -- player:setVariable("isMoving", false)
    player:setIgnoreMovement(false)
    player:setIgnoreInputsForDirection(false)
    player:setIgnoreAimingInput(false)

    local mount = commands.getAnimal(mountId)
    if mount then
        mount:setDir(player:getDir())
        MountedAnimationState.setMovementVariables(player, mount, false, false)
        MountedAnimationState.setTurnVariables(player, mount, 0)
        unlockMountedAnimal(mount)
        mount:setVariable(AnimationVariable.RIDING_HORSE, false)
        mount:setVariable(AnimationVariable.GALLOP, false)
        mount:setVariable(AnimationVariable.TROT, false)
        mount:setVariable(AnimationVariable.JUMP, false)

        -- used to reset the wander counter of the horse so it doesn't instantly wander off
        mount:setStateEventDelayTimer(mount:getBehavior():pickRandomWanderInterval())
    elseif not IS_CLIENT then
        -- it should only be possible on multiplayer clients for the mount to be unloaded
        log("WEIRD: player %s dismounted unknown animal id=%d", player:getUsername(), mountId)
    end

    if IS_SERVER then
        mountcommands.Dismount:send(
            nil,
            {
                character = commands.getPlayerId(player),
                animal = mountId
            }
        )
    end

    Mounts.onDismount:trigger(player, mount)
end

---@param player IsoPlayer
---@return boolean
---@nodiscard
function Mounts.hasMount(player)
    return playerMountMap[player] ~= nil
end


---@param player IsoPlayer
---@param windowMs integer
---@return boolean
---@nodiscard
function Mounts.wasRecentlyDismounted(player, windowMs)
    local ts = lastDismountTimestamps[player]
    if not ts then
        return false
    end
    return (getTimestampMs() - ts) < windowMs
end

---Returns a player's mount.
---Nil may be returned if the player is not mounted or the mount is not in the currently loaded area.
---Use :lua:obj:`hasMount` instead to check if the player is mounted.
---@param player IsoPlayer
---@return IsoAnimal? mount
---@nodiscard
function Mounts.getMount(player)
    if not playerMountMap[player] then
        return nil
    end

    return commands.getAnimal(playerMountMap[player])
end

---@param animal IsoAnimal
---@return boolean
---@nodiscard
function Mounts.hasRider(animal)
    return mountPlayerMap[commands.getAnimalId(animal)] ~= nil
end

---Returns an animal's rider.
---Nil may be returned if the animal is not mounted or the rider is not currently loaded.
---Use :lua:obj:`hasMount` instead to check if the player is mounted.
---@param animal IsoAnimal
---@return IsoPlayer? rider
---@nodiscard
function Mounts.getRider(animal)
    return mountPlayerMap[commands.getAnimalId(animal)]
end

function Mounts.reset()
    for player, _ in pairs(playerMountMap) do
        Mounts.removeMount(player)
    end
end

---@return table<integer|string, integer>
---@nodiscard
function Mounts.getSnapshot()
    local mounts = {}
    for player, animalId in pairs(playerMountMap) do
        mounts[commands.getPlayerId(player)] = animalId
    end

    return mounts
end

---@param callback fun(player: IsoPlayer, animal: IsoAnimal)
function Mounts.forEachLoadedMount(callback)
    for player, animalId in pairs(playerMountMap) do
        local animal = commands.getAnimal(animalId)
        if animal then
            callback(player, animal)
        end
    end
end

---@param recipient IsoPlayer?
function Mounts.sendMounts(recipient)
    if isClient() then
        return
    elseif isServer() then
        mountcommands.SendMounts:send(
            recipient,
            {
                mounts = Mounts.getSnapshot()
            }
        )
    else
        return
    end
end

---Keep mounted animals out of vanilla animal locomotion while riding owns transforms.
local function updateMounts()
    for player, mount in pairs(playerMountMap) do
        setMountedPlayerLock(player)

        local animal = commands.getAnimal(mount)
        if not animal then
            if IS_SERVER then
                log("WEIRD: tried to update unknown animal id=%d player=%s", mount, player:getUsername())
            end
        else
            setMountedAnimalLock(animal)
            -- the vanilla state machine only ticks in SP and on the MP server.
            -- Suppress alerted state there to stop Idle/Walk flipping near zombies
            if not IS_CLIENT then
                suppressMountedAnimalAI(animal)
            end
            syncMountedPlayerToAnimal(player, animal)
        end
    end
end

---@param character IsoGameCharacter
local function dismountOnDeath(character)
    if not instanceof(character, "IsoPlayer") then
        return
    end
    ---@cast character IsoPlayer

    Mounts.removeMount(character)
end

-- No reliable Lua event to use for detecting player disconnects
-- So if player disconnects while riding we need to clean up mounts at regular intervals
local function cleanupDisconnectedRiders()
    local mounted
    for player, _ in pairs(playerMountMap) do
        mounted = mounted or {}
        mounted[#mounted + 1] = player
    end

    if not mounted then
        return
    end

    local onlinePlayers = getOnlinePlayers()
    if not onlinePlayers then
        return
    end

    local online = {}
    for i = 0, onlinePlayers:size() - 1 do
        local p = onlinePlayers:get(i)
        if p then
            online[p:getUsername()] = true
        end
    end

    for _, player in ipairs(mounted) do
        if not online[player:getUsername()] then
            Mounts.removeMount(player)
        end
    end
end

if IS_CLIENT then
    Events.OnTickEvenPaused.Add(updateMounts)
    Events.OnTick.Add(updateMounts)
elseif IS_SERVER then
    Events.OnTickEvenPaused.Add(updateMounts)
    Events.OnTickEvenPaused.Add(cleanupDisconnectedRiders)
    Events.OnCharacterDeath.Add(dismountOnDeath)
else
    Events.OnTick.Add(updateMounts)
    Events.OnCharacterDeath.Add(dismountOnDeath)
end


-- we don't actually need these in singleplayer but networking.client complains if there is no handler
if not IS_SERVER then
    -- need to delay this require :(
    Events.OnInitGlobalModData.Add(function()
        local client = require("HorseMod/networking/client")

        client.registerCommandHandler(mountcommands.Mount, function(args)
            local player = commands.getPlayer(args.character)
            if player then
                local animal = commands.getAnimal(args.animal)
                if animal then
                    Mounts.addMount(player, animal)
                else
                    addMountID(player, args.animal)
                end
            else
                log("received Mount command for unknown player id=%s", tostring(args.character))
            end
        end)

        client.registerCommandHandler(mountcommands.Dismount, function(args)
            local player = commands.getPlayer(args.character)
            if not player and type(args.animal) == "number" then
                player = mountPlayerMap[args.animal]
            end
            if player then
                Mounts.removeMount(player)
            else
                log("received Dismount command for unknown player id=%s", tostring(args.character))
            end
        end)

        -- Server broadcast urgent dismounts so all remote clients see rider fall off/die
        client.registerCommandHandler(mountcommands.UrgentDismount, function(args)
            local player = commands.getPlayer(args.character)
            if player then
                player:setVariable(args.dismountType, true)
            else
                log("received UrgentDismount command for unknown player id=%s", tostring(args.character))
            end
        end)

        client.registerCommandHandler(mountcommands.SendMounts, function(args)
            Mounts.reset()

            for playerId, animalId in pairs(args.mounts) do
                local player = commands.getPlayer(playerId)
                local animal = commands.getAnimal(animalId)
                if not player then
                    log(
                        "could not find player or animal sent by server, player=%s animal=%d",
                        tostring(playerId),
                        animalId
                    )
                else
                    if animal then
                        Mounts.addMount(player, animal)
                    else
                        addMountID(player, animalId)
                    end
                end
            end
        end)
    end)
end


return Mounts
