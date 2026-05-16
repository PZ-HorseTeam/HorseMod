if isClient() then
    return
end

---@namespace HorseMod

local Mounts = require("HorseMod/Mounts")
local Stamina = require("HorseMod/Stamina")
local AnimationVariable = require("HorseMod/definitions/AnimationVariable")
local MountedAnimationState = require("HorseMod/riding/MountedAnimationState")
local MountedDirection = require("HorseMod/riding/MountedDirection")
local mountcommands = require("HorseMod/networking/mountcommands")
local commands = require("HorseMod/networking/commands")
local server = require("HorseMod/networking/server")

local INPUT_TIMEOUT_SECONDS = 0.35
local HEARTBEAT_INTERVAL_SECONDS = 0.25
local RESYNC_SEQ_GAP = 30
local MAX_MOUNT_DISTANCE_SQ = 144
local MAX_CLIENT_POSE_DISTANCE_SQ = 64
local MAX_INPUT_AXIS = 1.05
local MAX_CLIENT_SPEED = 24
local MAX_CLIENT_Z_DELTA = 2
local TURN_ANIM_HOLD_SECONDS = 0.20
local IDLE_TO_RUN_SECONDS = 0.6

---@class ServerRidingState
---@field rider IsoPlayer
---@field animal IsoAnimal
---@field seq integer
---@field lastSpeed number
---@field lastGallop boolean
---@field lastTrot boolean
---@field lastJump boolean
---@field lastMoving boolean
---@field lastDir integer
---@field lastTurn integer
---@field lastTurnTime number
---@field lastHasReins boolean
---@field timeSinceInput number
---@field timeSinceHeartbeat number
---@field idleToRunTime number

---@type table<IsoPlayer, ServerRidingState>
local states = {}

---@class ClientRidingPose
---@field x number
---@field y number
---@field z number
---@field dir integer
---@field speed number

---@class ValidatedRidingInput : RidingMovementInput
---@field hasReins boolean

---@param value any
---@return number?
---@nodiscard
local function sanitizeAxis(value)
    if type(value) ~= "number" then
        return nil
    end

    if math.abs(value) > MAX_INPUT_AXIS then
        return nil
    end

    if value > 1 then
        return 1
    elseif value < -1 then
        return -1
    end

    return value
end

---@param value any
---@return number?
---@nodiscard
local function sanitizeSpeed(value)
    if type(value) ~= "number" then
        return nil
    end

    if value < 0 or value > MAX_CLIENT_SPEED then
        return nil
    end

    return value
end

---@param args RidingInputArguments
---@param animal IsoAnimal
---@return ClientRidingPose?
---@nodiscard
local function validateClientPose(args, animal)
    if type(args.x) ~= "number"
            or type(args.y) ~= "number"
            or type(args.z) ~= "number"
            or type(args.dir) ~= "number" then
        return nil
    end

    local speed = sanitizeSpeed(args.speed)
    if not speed then
        return nil
    end

    if math.abs(args.z - animal:getZ()) > MAX_CLIENT_Z_DELTA then
        return nil
    end

    local dir = math.floor(args.dir)
    if dir < 0 or dir > 7 then
        return nil
    end

    local dx = animal:getX() - args.x
    local dy = animal:getY() - args.y
    local dz = animal:getZ() - args.z
    if (dx * dx + dy * dy + dz * dz) > MAX_CLIENT_POSE_DISTANCE_SQ then
        return nil
    end

    return {
        x = args.x,
        y = args.y,
        z = args.z,
        dir = dir,
        speed = speed,
    }
end

---@param oldDir integer
---@param newDir integer
---@param previousTurn integer
---@return integer
---@nodiscard
local function getTurnFromDirectionDelta(oldDir, newDir, previousTurn)
    local rightSteps = (newDir - oldDir) % 8
    if rightSteps == 0 then
        return 0
    elseif rightSteps < 4 then
        return 1
    elseif rightSteps > 4 then
        return -1
    elseif previousTurn ~= 0 then
        return previousTurn
    end

    return 1
end

---@param player IsoPlayer
---@param args RidingInputArguments
---@return IsoAnimal?, ValidatedRidingInput?, integer?, ClientRidingPose?
---@nodiscard
local function validateInput(player, args)
    if type(args.animal) ~= "number" or type(args.seq) ~= "number" then
        return nil
    end

    local moveX = sanitizeAxis(args.moveX)
    local moveY = sanitizeAxis(args.moveY)
    if not moveX or not moveY then
        return nil
    end

    local animal = commands.getAnimal(math.floor(args.animal))
    if not animal then
        return nil
    end

    if animal:isDead() then
        return nil
    end

    if Mounts.getMount(player) ~= animal then
        return nil
    end

    if player:DistToSquared(animal:getX(), animal:getY()) > MAX_MOUNT_DISTANCE_SQ then
        return nil
    end

    local input = {
        movement = {
            x = moveX,
            y = moveY,
        },
        run = args.run == true,
        trot = args.trot == true,
        jump = args.jump == true,
        hasReins = args.hasReins == true,
    }

    local moving = moveX ~= 0 or moveY ~= 0
    if input.run and not Stamina.shouldRun(animal, input, moving) then
        input.run = false
    end

    local pose = validateClientPose(args, animal)
    if not pose then
        return nil
    end

    return animal, input, math.floor(args.seq), pose
end

---@param state ServerRidingState
---@param input ValidatedRidingInput
---@param pose ClientRidingPose
local function applyClientPose(state, input, pose)
    local animal = state.animal
    local rider = state.rider

    animal:setX(pose.x)
    animal:setY(pose.y)
    animal:setZ(pose.z)
    rider:setForceX(pose.x)
    rider:setForceY(pose.y)
    rider:setZ(pose.z)

    local dir = IsoDirections.fromIndex(pose.dir)
    MountedDirection.set(rider, animal, dir)

    local moving = pose.speed > 0
    local galloping = moving and input.run
    local turn = getTurnFromDirectionDelta(state.lastDir, pose.dir, state.lastTurn)
    if turn ~= 0 then
        state.lastTurn = turn
        state.lastTurnTime = TURN_ANIM_HOLD_SECONDS
    end

    animal:setVariable(AnimationVariable.GALLOP, galloping)
    animal:setVariable(AnimationVariable.TROT, input.trot == true)
    animal:setVariable(AnimationVariable.JUMP, input.jump == true)

    rider:setVariable(AnimationVariable.GALLOP, galloping)
    rider:setVariable(AnimationVariable.TROT, input.trot == true)
    rider:setVariable(AnimationVariable.JUMP, input.jump == true)
    MountedAnimationState.setSpeedVariables(rider, animal)
    MountedAnimationState.setMovementVariables(rider, animal, moving, galloping)
    MountedAnimationState.setTurnVariables(rider, animal, state.lastTurn)
    MountedAnimationState.setReinsVariable(rider, input.hasReins)

    if galloping and not state.lastGallop then
        state.idleToRunTime = IDLE_TO_RUN_SECONDS
    elseif not galloping then
        state.idleToRunTime = 0
    end

    state.lastSpeed = pose.speed
    state.lastMoving = moving
    state.lastGallop = galloping
    state.lastTrot = input.trot == true
    state.lastJump = input.jump == true
    state.lastDir = pose.dir
    state.lastHasReins = input.hasReins
end

---@param state ServerRidingState
---@return RidingStateArguments
---@nodiscard
local function buildStateArgs(state)
    local animal = state.animal
    local turn = 0
    if state.lastTurnTime > 0 then
        turn = state.lastTurn
    end

    return {
        character = commands.getPlayerId(state.rider),
        animal = commands.getAnimalId(animal),
        seq = state.seq,
        x = animal:getX(),
        y = animal:getY(),
        z = animal:getZ(),
        dir = state.lastDir,
        speed = state.lastSpeed,
        gallop = state.lastGallop,
        trot = state.lastTrot,
        jump = state.lastJump,
        turn = turn,
        hasReins = state.lastHasReins,
        idleToRun = (not state.lastGallop) or state.idleToRunTime > 0,
    }
end

---@param state ServerRidingState
---@param excludeRider boolean
local function relayRidingState(state, excludeRider)
    local args = buildStateArgs(state)
    local rider = state.rider

    local players = getOnlinePlayers()
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if not excludeRider or player ~= rider then
            mountcommands.RidingState:send(player, args)
        end
    end

    state.timeSinceHeartbeat = 0
end

---@param player IsoPlayer
---@param animal IsoAnimal
---@return ServerRidingState
local function getOrCreateState(player, animal)
    local state = states[player]
    if state and state.animal == animal then
        return state
    end

    state = {
        rider = player,
        animal = animal,
        seq = 0,
        lastSpeed = 0,
        lastGallop = false,
        lastTrot = animal:getVariableBoolean(AnimationVariable.TROT),
        lastJump = false,
        lastMoving = false,
        lastDir = player:getDir():ordinal(),
        lastTurn = 0,
        lastTurnTime = 0.0,
        lastHasReins = player:getVariableBoolean(AnimationVariable.HAS_REINS),
        timeSinceInput = INPUT_TIMEOUT_SECONDS,
        timeSinceHeartbeat = 0,
        idleToRunTime = 0.0,
    }
    states[player] = state

    return state
end

---@param player IsoPlayer
---@param args RidingInputArguments
local function handleRidingInput(player, args)
    local animal, input, seq, pose = validateInput(player, args)
    if not animal or not input or not seq or not pose then
        return
    end

    local state = getOrCreateState(player, animal)
    if seq < state.seq then
        return
    end

    local gap = seq - state.seq
    state.seq = seq
    state.timeSinceInput = 0
    applyClientPose(state, input, pose)

    if gap > RESYNC_SEQ_GAP then
        mountcommands.RidingState:send(player, buildStateArgs(state))
    end

    relayRidingState(state, true)
end

---@param player IsoPlayer
---@param args RequestMountsArguments
local function handleRequestMounts(player, args)
    Mounts.sendMounts(player)

    Mounts.forEachLoadedMount(function(mountedPlayer, animal)
        local state = getOrCreateState(mountedPlayer, animal)
        mountcommands.RidingState:send(player, buildStateArgs(state))
    end)
end

---@param player IsoPlayer
---@param animal IsoAnimal?
local function handleMountChanged(player, animal)
    if animal then
        getOrCreateState(player, animal)
    else
        states[player] = nil
    end
end

local function updateMountedMovement()
    local delta = GameTime.getInstance():getTimeDelta()

    for player, state in pairs(states) do repeat
        local animal = Mounts.getMount(player)
        if not animal or animal ~= state.animal then
            states[player] = nil
            break
        end

        state.timeSinceInput = state.timeSinceInput + delta
        state.timeSinceHeartbeat = state.timeSinceHeartbeat + delta
        if state.lastTurnTime > 0 then
            state.lastTurnTime = math.max(0, state.lastTurnTime - delta)
            if state.lastTurnTime == 0 then
                state.lastTurn = 0
                MountedAnimationState.setTurnVariables(state.rider, animal, 0)
            end
        end
        if state.idleToRunTime > 0 then
            state.idleToRunTime = math.max(0, state.idleToRunTime - delta)
        end

        if state.timeSinceInput > INPUT_TIMEOUT_SECONDS and state.lastMoving then
            animal:setVariable(AnimationVariable.GALLOP, false)
            animal:setVariable(AnimationVariable.JUMP, false)
            state.rider:setVariable(AnimationVariable.GALLOP, false)
            state.rider:setVariable(AnimationVariable.JUMP, false)
            MountedAnimationState.setMovementVariables(state.rider, animal, false, false)
            MountedAnimationState.setTurnVariables(state.rider, animal, 0)

            state.lastSpeed = 0
            state.lastMoving = false
            state.lastGallop = false
            state.lastJump = false
            state.lastTurn = 0
            state.lastTurnTime = 0
            state.idleToRunTime = 0
            relayRidingState(state, true)
        elseif state.timeSinceHeartbeat >= HEARTBEAT_INTERVAL_SECONDS then
            relayRidingState(state, true)
        end
    until true end
end

---@type table<string, true>
local VALID_DISMOUNT_ATTACHMENTS = {
    mountLeft = true,
    mountRight = true,
}

---@param player IsoPlayer
---@param args MountRequestArguments
local function handleMountRequest(player, args)
    if type(args.animal) ~= "number" then
        return
    end

    local animal = commands.getAnimal(math.floor(args.animal))
    if not animal then
        return
    end

    if animal:isDead() then
        return
    end

    if Mounts.hasMount(player) then
        return
    end

    if Mounts.hasRider(animal) then
        return
    end

    if player:DistToSquared(animal:getX(), animal:getY()) > MAX_MOUNT_DISTANCE_SQ then
        return
    end

    Mounts.addMount(player, animal)
end

---@param player IsoPlayer
---@param args DismountRequestArguments
local function handleDismountRequest(player, args)
    if type(args.animal) ~= "number" or type(args.attachment) ~= "string" then
        return
    end

    if not VALID_DISMOUNT_ATTACHMENTS[args.attachment] then
        return
    end

    local animal = commands.getAnimal(math.floor(args.animal))
    if not animal then
        return
    end

    if Mounts.getMount(player) ~= animal then
        return
    end

    local attachmentPosition = animal:getAttachmentWorldPos(args.attachment)
    if attachmentPosition then
        player:setX(attachmentPosition:x())
        player:setY(attachmentPosition:y())
        player:setZ(animal:getZ())
    end

    Mounts.removeMount(player)
end

server.registerCommandHandler(mountcommands.RidingInput, handleRidingInput)
server.registerCommandHandler(mountcommands.RequestMounts, handleRequestMounts)
server.registerCommandHandler(mountcommands.MountRequest, handleMountRequest)
server.registerCommandHandler(mountcommands.DismountRequest, handleDismountRequest)

Mounts.onMountChanged:add(handleMountChanged)
Events.OnTickEvenPaused.Add(updateMountedMovement)

return states
