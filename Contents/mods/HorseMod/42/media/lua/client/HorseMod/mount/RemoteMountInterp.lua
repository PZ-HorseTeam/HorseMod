---@namespace HorseMod

local AnimationVariable = require("HorseMod/definitions/AnimationVariable")
local HorseManager = require("HorseMod/HorseManager")
local MountedAnimationState = require("HorseMod/riding/MountedAnimationState")
local MountedDirection = require("HorseMod/riding/MountedDirection")
local Mounts = require("HorseMod/Mounts")
local RemoteRiderPin = require("HorseMod/mount/RemoteRiderPin")

---@class RemoteMountSnapshot
---@field x number
---@field y number
---@field z number
---@field dir integer
---@field speed number
---@field turn integer

---@class RemoteMountEntry
---@field rider IsoPlayer
---@field animal IsoAnimal
---@field prev RemoteMountSnapshot?
---@field next RemoteMountSnapshot
---@field turn integer
---@field interval number
---@field timeSinceNext number
---@field timeSinceAnyPush number
---@field lastArgs table

local RemoteMountInterp = {}

local MIN_INTERVAL = 0.02
local MAX_INTERVAL = 0.5
local EXTRAPOLATE_LIMIT = 1.1
-- Must stay well clear of the server's one second stationary heartbeat, or a
-- single late packet stops a parked rider being reasserted.
local STALE_SECONDS = 3.0
local MOUNTED_TURN_DELTA = 0.65


---@type table<IsoPlayer, RemoteMountEntry>
local entries = {}

---@param a number
---@param b number
---@param t number
---@return number
---@nodiscard
local function lerp(a, b, t)
    return a + (b - a) * t
end

---@param args table
---@return RemoteMountSnapshot
---@nodiscard
local function snapshotFromArgs(args)
    return {
        x = args.x,
        y = args.y,
        z = args.z,
        dir = math.floor(args.dir),
        speed = args.speed,
        turn = args.turn,
    }
end

---@param args table
---@return integer
---@nodiscard
local function getTurnFromArgs(args)
    if type(args.turn) ~= "number" then
        return 0
    end

    local turn = math.floor(args.turn)
    if turn < 0 then
        return -1
    elseif turn > 0 then
        return 1
    end

    return 0
end

---@param animal IsoAnimal
---@param isMoving boolean
local function prepareRemoteMount(animal, isMoving)
    animal:stopAllMovementNow()
    animal:setTurnDelta(MOUNTED_TURN_DELTA)
end

---@param rider IsoPlayer
---@param animal IsoAnimal
---@param args table
local function applyAnimVars(rider, animal, args)
    local galloping = args.gallop == true
    local trotting = args.trot == true
    local jumping = args.jump == true
    local moving = args.speed > 0

    animal:setVariable(AnimationVariable.RIDING_HORSE, true)
    animal:setVariable(AnimationVariable.GALLOP, galloping)
    animal:setVariable(AnimationVariable.TROT, trotting)
    animal:setVariable(AnimationVariable.JUMP, jumping)

    rider:setVariable(AnimationVariable.RIDING_HORSE, true)
    rider:setVariable(AnimationVariable.GALLOP, galloping)
    rider:setVariable(AnimationVariable.TROT, trotting)
    rider:setVariable(AnimationVariable.JUMP, jumping)

    MountedAnimationState.setMovementVariables(rider, animal, moving, galloping)
    MountedAnimationState.setTurnVariables(rider, animal, getTurnFromArgs(args))
    MountedAnimationState.setReinsVariable(rider, args.hasReins == true)
end

---@param rider IsoPlayer
---@param animal IsoAnimal
---@param args table
function RemoteMountInterp.push(rider, animal, args)
    if not Mounts.hasMount(rider) then
        if Mounts.wasRecentlyDismounted(rider, 1500) then
            return
        end
        Mounts.addMount(rider, animal)
    end

    local snapshot = snapshotFromArgs(args)
    prepareRemoteMount(animal, args.speed > 0)

    local entry = entries[rider]
    if not entry or entry.animal ~= animal then
        if entry and entry.animal then
            MountedDirection.clear(entry.animal)
        end
        entry = {
            rider = rider,
            animal = animal,
            prev = nil,
            next = snapshot,
            turn = getTurnFromArgs(args),
            interval = 0.05,
            timeSinceNext = 0,
            timeSinceAnyPush = 0,
            lastArgs = args,
        }
        entries[rider] = entry
        Mounts.setInterpolated(rider, true)
        MountedAnimationState.setSpeedVariables(rider, animal)
        animal:setX(snapshot.x)
        animal:setY(snapshot.y)
        animal:setZ(snapshot.z)
        MountedDirection.clear(animal)
        local direction = IsoDirections.fromIndex(snapshot.dir)
        MountedDirection.set(rider, animal, direction, nil, true)
        RemoteRiderPin.pinRiderToPosition(
            rider,
            snapshot.x,
            snapshot.y,
            snapshot.z,
            direction
        )
        prepareRemoteMount(animal, args.speed > 0)
        applyAnimVars(rider, animal, args)
        return
    end

    local observedInterval = entry.timeSinceNext
    if observedInterval >= MIN_INTERVAL then
        if observedInterval > MAX_INTERVAL then
            observedInterval = MAX_INTERVAL
        end
        entry.interval = observedInterval
    end

    entry.prev = entry.next
    entry.next = snapshot
    entry.turn = getTurnFromArgs(args)
    entry.timeSinceNext = 0
    entry.timeSinceAnyPush = 0
    entry.lastArgs = args
    prepareRemoteMount(animal, args.speed > 0)
    MountedAnimationState.setSpeedVariables(rider, animal)
    applyAnimVars(rider, animal, args)
    RemoteRiderPin.pinRiderToPosition(
        rider,
        snapshot.x,
        snapshot.y,
        snapshot.z,
        IsoDirections.fromIndex(snapshot.dir)
    )
end

---@param rider IsoPlayer
function RemoteMountInterp.clear(rider)
    local entry = entries[rider]
    if entry and entry.animal then
        MountedDirection.clear(entry.animal)
    end
    entries[rider] = nil
    Mounts.setInterpolated(rider, false)
end

local function update()
    local delta = GameTime.getInstance():getTimeDelta()

    for rider, entry in pairs(entries) do repeat
        local animal = entry.animal
        if not animal or animal:isDead() or not animal:isExistInTheWorld() then
            if animal then
                MountedDirection.clear(animal)
            end
            entries[rider] = nil
            Mounts.setInterpolated(rider, false)
            break
        end

        entry.timeSinceNext = entry.timeSinceNext + delta
        entry.timeSinceAnyPush = entry.timeSinceAnyPush + delta

        if entry.timeSinceAnyPush > STALE_SECONDS then
            break
        end

        local target = entry.next
        local source = entry.prev or target

        -- Every frame, not on a timer: the vanilla state machine clobbers these
        -- continuously, and a remote rider reverts to on-foot animation the moment
        -- they go unasserted.
        prepareRemoteMount(animal, target.speed > 0)
        applyAnimVars(rider, animal, entry.lastArgs)

        local interval = entry.interval
        local t = entry.timeSinceNext / interval
        if t < 0 then t = 0 end
        if t > EXTRAPOLATE_LIMIT then t = EXTRAPOLATE_LIMIT end

        local x = lerp(source.x, target.x, t)
        local y = lerp(source.y, target.y, t)
        local z = lerp(source.z, target.z, t)

        animal:setX(x)
        animal:setY(y)
        animal:setZ(z)

        local direction = IsoDirections.fromIndex(target.dir)
        MountedDirection.set(rider, animal, direction, delta, true)
        RemoteRiderPin.pinRiderToPosition(rider, x, y, z, direction)
    until true end
end

HorseManager.preUpdate:add(update)

return RemoteMountInterp
