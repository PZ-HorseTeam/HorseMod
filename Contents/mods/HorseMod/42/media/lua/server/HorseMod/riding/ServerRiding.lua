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
local soundcommands = require("HorseMod/networking/soundcommands")
local commands = require("HorseMod/networking/commands")
local netmetrics = require("HorseMod/networking/netmetrics")
local relevance = require("HorseMod/networking/relevance")
local ridingcodec = require("HorseMod/networking/ridingcodec")
local server = require("HorseMod/networking/server")

local INPUT_TIMEOUT_SECONDS = 0.35
local JUMP_COOLDOWN_MS = 1200
local RESYNC_SEQ_GAP = 30
local MAX_MOUNT_DISTANCE_SQ = 144
local MAX_CLIENT_POSE_DISTANCE_SQ = 64
local MAX_INPUT_AXIS = 1.05
local MAX_CLIENT_SPEED = 24
local MAX_CLIENT_Z_DELTA = 2
local TURN_ANIM_HOLD_SECONDS = 0.20
local IDLE_TO_RUN_SECONDS = 0.6

-- A dedicated server ticks around 10 Hz with a per-tick delta near 0.1, so an
-- interval of 0.1 needs TWO ticks and silently halves the rate. Keep these under
-- one tick period so the threshold is met on the tick it is due.
local ROUTE_INTERVAL_SECONDS = 0.05
local MOVING_SEND_INTERVAL_SECONDS = 0.1
-- Trot and gallop both cover enough ground per snapshot that 5 Hz reads as
-- teleporting. Walking still looks fine at the slower rate.
local FAST_SEND_INTERVAL_SECONDS = 0.05
local IDLE_SEND_INTERVAL_SECONDS = 1.0
local RANGE_SWEEP_INTERVAL_SECONDS = 1.0
local ONLINE_CACHE_MS = 50

---@class ServerRidingState
---@field rider IsoPlayer
---@field animal IsoAnimal
---@field seq integer
---@field outSeq integer
---@field lastSpeed number
---@field lastGallop boolean
---@field lastTrot boolean
---@field lastJump boolean
---@field lastJumpAcceptedMs integer
---@field lastMoving boolean
---@field lastDir integer
---@field lastTurn integer
---@field lastTurnTime number
---@field lastHasReins boolean
---@field lastGait MovementState
---@field timeSinceInput number
---@field timeSinceRoute number
---@field timeSinceSend number
---@field idleToRunTime number
---@field semanticDirty boolean
---@field sentX number
---@field sentY number
---@field sentZ number
---@field routePass integer
---@field observers table<IsoPlayer, integer>

---@type table<IsoPlayer, ServerRidingState>
local states = {}

---Approximated relevance range in tiles, reported by each client on join.
---@type table<IsoPlayer, integer>
local playerRanges = {}

---@type IsoPlayer[]
local onlineScratch = {}
local onlineCount = 0
local onlineCacheStamp = 0

---@type table<IsoPlayer, true>
local onlineSetScratch = {}

local rangeSweepTimer = 0
local routeStagger = 0

---@class ClientRidingPose
---@field x number
---@field y number
---@field z number
---@field dir integer
---@field speed number

---@class ValidatedRidingInput : RidingMovementInput
---@field hasReins boolean

local function refreshOnlinePlayers()
    local now = getTimestampMs()
    if now - onlineCacheStamp < ONLINE_CACHE_MS then
        return
    end
    onlineCacheStamp = now

    local previousCount = onlineCount
    onlineCount = 0

    local players = getOnlinePlayers()
    if players then
        for i = 0, players:size() - 1 do
            local player = players:get(i)
            if player then
                onlineCount = onlineCount + 1
                onlineScratch[onlineCount] = player
            end
        end
    end

    for i = onlineCount + 1, previousCount do
        onlineScratch[i] = nil
    end
end

---@param player IsoPlayer
---@return integer
---@nodiscard
local function getRelevanceRange(player)
    local range = playerRanges[player]
    if not range then
        return relevance.MAX_RANGE_TILES
    end

    return range
end

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

---Derive the rider's current gait from server-authoritative state. Used to
---broadcast HorseSoundState so remote clients can drive the footstep loop.
---@param moving boolean
---@param galloping boolean
---@param trotting boolean
---@return MovementState
---@nodiscard
local function deriveGait(moving, galloping, trotting)
    if galloping then
        return "gallop"
    end
    if not moving then
        return "idle"
    end
    if trotting then
        return "trot"
    end
    return "walking"
end

---@param state ServerRidingState
---@param gait MovementState
---@param jumping boolean
---@return HorseSoundStateArguments
---@nodiscard
local function buildGaitArgs(state, gait, jumping)
    return {
        rider = commands.getPlayerId(state.rider),
        animal = commands.getAnimalId(state.animal),
        gait = gait,
        jumping = jumping,
    }
end

---Only observers that can load the horse can do anything with a gait change;
---everyone else drops the packet after resolving the animal to nil.
---@param state ServerRidingState
---@param gait MovementState
---@param jumping boolean
local function sendGaitToObservers(state, gait, jumping)
    local args = nil
    for player in pairs(state.observers) do
        if not args then
            args = buildGaitArgs(state, gait, jumping)
        end
        soundcommands.HorseSoundState:send(player, args)
    end
end

---@param state ServerRidingState
---@param player IsoPlayer
local function sendGaitToObserver(state, player)
    soundcommands.HorseSoundState:send(
        player,
        buildGaitArgs(state, state.lastGait, state.lastJump)
    )
end

---@param state ServerRidingState
---@param gait MovementState
---@param jumping boolean
local function broadcastGaitIfChanged(state, gait, jumping)
    if state.lastGait == gait then
        return
    end
    state.lastGait = gait

    sendGaitToObservers(state, gait, jumping)
end

---Everything a remote observer needs immediately, with direction and position
---left out because those follow the movement cadence instead.
---@param state ServerRidingState
---@return integer
---@nodiscard
local function semanticSignature(state)
    local turn = 0
    if state.lastTurnTime > 0 then
        turn = state.lastTurn
    end

    local signature = turn + 1
    if state.lastGallop then
        signature = signature + 4
    end
    if state.lastTrot then
        signature = signature + 8
    end
    if state.lastJump then
        signature = signature + 16
    end
    if state.lastHasReins then
        signature = signature + 32
    end
    if state.lastMoving then
        signature = signature + 64
    end
    if (not state.lastGallop) or state.idleToRunTime > 0 then
        signature = signature + 128
    end

    return signature
end

---@param state ServerRidingState
---@param input ValidatedRidingInput
---@param pose ClientRidingPose
local function applyClientPose(state, input, pose)
    local animal = state.animal
    local rider = state.rider
    local previousSignature = semanticSignature(state)

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

    if input.jump and not state.lastJump then
        local now = getTimestampMs()
        if now - state.lastJumpAcceptedMs < JUMP_COOLDOWN_MS then
            input.jump = false
        else
            state.lastJumpAcceptedMs = now
        end
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

    if semanticSignature(state) ~= previousSignature then
        state.semanticDirty = true
    end

    broadcastGaitIfChanged(state, deriveGait(moving, galloping, input.trot == true), input.jump == true)
end

---Builds a complete snapshot and consumes one outbound sequence number.
---@param state ServerRidingState
---@return RidingStateArguments
local function buildStateArgs(state)
    local animal = state.animal
    local turn = 0
    if state.lastTurnTime > 0 then
        turn = state.lastTurn
    end

    state.outSeq = state.outSeq + 1

    if netmetrics.enabled then
        netmetrics.count("riding.snapshotsBuilt")
    end

    return {
        character = ridingcodec.encodePlayerId(state.rider),
        animal = commands.getAnimalId(animal),
        seq = state.outSeq,
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

---Sends a complete snapshot to every observer that can currently load the
---horse. Observers that only just entered the relevance area are always served,
---even when the cadence has nothing else to say.
---@param state ServerRidingState
---@param reason string? Nil sends to newly relevant observers only.
local function routeRidingState(state, reason)
    local rider = state.rider
    local animal = state.animal
    local animalX = animal:getX()
    local animalY = animal:getY()
    local observers = state.observers
    local metricsEnabled = netmetrics.enabled

    local pass = state.routePass + 1
    state.routePass = pass

    refreshOnlinePlayers()

    ---@type RidingStateWire?
    local wire = nil
    local relevantCount = 0
    local sentCount = 0

    for i = 1, onlineCount do
        local player = onlineScratch[i]
        if player ~= rider then
            local inRange = relevance.isInRange(
                animalX,
                animalY,
                player:getX(),
                player:getY(),
                getRelevanceRange(player)
            )

            if inRange then
                relevantCount = relevantCount + 1
                local isNewObserver = observers[player] == nil
                observers[player] = pass

                if isNewObserver or reason then
                    if not wire then
                        wire = ridingcodec.encode(buildStateArgs(state))
                    end
                    mountcommands.RidingState:send(player, wire)
                    sentCount = sentCount + 1

                    if isNewObserver and state.lastGait ~= "idle" then
                        sendGaitToObserver(state, player)
                    end

                    if metricsEnabled then
                        if isNewObserver then
                            netmetrics.count("riding.send.entry")
                        else
                            netmetrics.count("riding.send." .. reason)
                        end
                    end
                end
            end
        end
    end

    for player, seenPass in pairs(observers) do
        if seenPass ~= pass then
            observers[player] = nil
        end
    end

    if reason then
        state.semanticDirty = false
        state.timeSinceSend = 0
        state.sentX = animalX
        state.sentY = animalY
        state.sentZ = animal:getZ()
    end

    if metricsEnabled then
        netmetrics.count("riding.candidatesChecked", onlineCount)
        netmetrics.count("riding.observersRelevant", relevantCount)
        netmetrics.count("riding.packetsSent", sentCount)
    end
end

---@param player IsoPlayer
---@param animal IsoAnimal
---@return ServerRidingState
local function getOrCreateState(player, animal)
    local state = states[player]
    if state and state.animal == animal then
        return state
    end

    routeStagger = (routeStagger + 1) % 6

    state = {
        rider = player,
        animal = animal,
        seq = 0,
        outSeq = 0,
        lastSpeed = 0,
        lastGallop = false,
        lastTrot = animal:getVariableBoolean(AnimationVariable.TROT),
        lastJump = false,
        lastJumpAcceptedMs = 0,
        lastMoving = false,
        lastDir = player:getDir():ordinal(),
        lastTurn = 0,
        lastTurnTime = 0.0,
        lastHasReins = player:getVariableBoolean(AnimationVariable.HAS_REINS),
        lastGait = "idle",
        timeSinceInput = INPUT_TIMEOUT_SECONDS,
        timeSinceRoute = routeStagger * (ROUTE_INTERVAL_SECONDS / 6),
        timeSinceSend = IDLE_SEND_INTERVAL_SECONDS,
        idleToRunTime = 0.0,
        semanticDirty = false,
        sentX = animal:getX(),
        sentY = animal:getY(),
        sentZ = animal:getZ(),
        routePass = 0,
        observers = {},
    }
    states[player] = state

    return state
end

---@param player IsoPlayer
---@param args RidingInputArguments
local function handleRidingInput(player, args)
    if netmetrics.enabled then
        netmetrics.count("riding.inputsReceived")
    end

    local animal, input, seq, pose = validateInput(player, args)
    if not animal or not input or not seq or not pose then
        if netmetrics.enabled then
            netmetrics.count("riding.inputsInvalid")
        end
        return
    end

    local state = getOrCreateState(player, animal)
    if seq < state.seq then
        if netmetrics.enabled then
            netmetrics.count("riding.inputsStale")
        end
        return
    end

    local gap = seq - state.seq
    state.seq = seq
    state.timeSinceInput = 0
    applyClientPose(state, input, pose)

    if netmetrics.enabled then
        netmetrics.count("riding.inputsAccepted")
    end

    if gap > RESYNC_SEQ_GAP then
        mountcommands.RidingState:send(player, ridingcodec.encode(buildStateArgs(state)))
    end

    if state.semanticDirty then
        routeRidingState(state, "semantic")
    end
end

---@param player IsoPlayer
---@param args RequestMountsArguments
local function handleRequestMounts(player, args)
    playerRanges[player] = relevance.sanitizeReportedWidth(args.w)

    Mounts.sendMounts(player)

    local range = playerRanges[player]
    local playerX = player:getX()
    local playerY = player:getY()

    Mounts.forEachLoadedMount(function(mountedPlayer, animal)
        local isSelf = mountedPlayer == player
        if not isSelf and not relevance.isInRange(animal:getX(), animal:getY(), playerX, playerY, range) then
            return
        end

        local state = getOrCreateState(mountedPlayer, animal)
        if not isSelf then
            state.observers[player] = state.routePass
        end
        mountcommands.RidingState:send(player, ridingcodec.encode(buildStateArgs(state)))
    end)
end

local function sweepRelevanceRanges()
    refreshOnlinePlayers()

    for player in pairs(onlineSetScratch) do
        onlineSetScratch[player] = nil
    end

    for i = 1, onlineCount do
        onlineSetScratch[onlineScratch[i]] = true
    end

    for player in pairs(playerRanges) do
        if not onlineSetScratch[player] then
            playerRanges[player] = nil
        end
    end
end

---@param state ServerRidingState
---@return number
---@nodiscard
local function movingSendInterval(state)
    if state.lastGallop or state.lastTrot then
        return FAST_SEND_INTERVAL_SECONDS
    end

    return MOVING_SEND_INTERVAL_SECONDS
end

---@param state ServerRidingState
---@return boolean
---@nodiscard
local function hasPositionChanged(state)
    local animal = state.animal
    return animal:getX() ~= state.sentX
        or animal:getY() ~= state.sentY
        or animal:getZ() ~= state.sentZ
end

local function updateMountedMovement()
    local delta = GameTime.getInstance():getTimeDelta()

    rangeSweepTimer = rangeSweepTimer + delta
    if rangeSweepTimer >= RANGE_SWEEP_INTERVAL_SECONDS then
        rangeSweepTimer = 0
        sweepRelevanceRanges()
    end

    for player, state in pairs(states) do repeat
        local animal = Mounts.getMount(player)
        if not animal or animal ~= state.animal then
            states[player] = nil
            break
        end

        state.timeSinceInput = state.timeSinceInput + delta
        state.timeSinceRoute = state.timeSinceRoute + delta
        state.timeSinceSend = state.timeSinceSend + delta
        if state.lastTurnTime > 0 then
            state.lastTurnTime = math.max(0, state.lastTurnTime - delta)
            if state.lastTurnTime == 0 then
                state.lastTurn = 0
                MountedAnimationState.setTurnVariables(state.rider, animal, 0)
                state.semanticDirty = true
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
            state.timeSinceRoute = 0
            broadcastGaitIfChanged(state, "idle", false)
            routeRidingState(state, "timeout")
            break
        end

        if state.timeSinceRoute < ROUTE_INTERVAL_SECONDS then
            break
        end
        state.timeSinceRoute = 0

        local reason = nil
        if state.semanticDirty then
            reason = "semantic"
        elseif hasPositionChanged(state) and state.timeSinceSend >= movingSendInterval(state) then
            reason = "movement"
        elseif state.timeSinceSend >= IDLE_SEND_INTERVAL_SECONDS then
            reason = "heartbeat"
        end

        routeRidingState(state, reason)
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

local function handleHorseFleeRequest(player, args)
    if type(args.animal) ~= "number" or type(args.attachment) ~= "string" then
        return
    end

    local animal = commands.getAnimal(math.floor(args.animal))
    if not animal then
        return
    end

    animal:getBehavior():forceFleeFromChr(player)
end


---@param player IsoPlayer
---@param animal IsoAnimal
local function handleMount(player, animal)
    getOrCreateState(player, animal)
end

---@param player IsoPlayer
---@param animal IsoAnimal?
local function handleDismount(player, animal)
    local state = states[player]
    if state and animal then
        -- Push a final idle so remote clients silence the footstep loop even
        -- if they haven't yet received the Dismount packet.
        broadcastGaitIfChanged(state, "idle", false)
    end
    states[player] = nil
end


server.registerCommandHandler(mountcommands.RidingInput, handleRidingInput)
server.registerCommandHandler(mountcommands.RequestMounts, handleRequestMounts)
server.registerCommandHandler(mountcommands.MountRequest, handleMountRequest)
server.registerCommandHandler(mountcommands.DismountRequest, handleDismountRequest)
server.registerCommandHandler(mountcommands.HorseFleeRequest, handleHorseFleeRequest)

Mounts.onMount:add(handleMount)
Mounts.onDismount:add(handleDismount)
Events.OnTickEvenPaused.Add(updateMountedMovement)

return states
