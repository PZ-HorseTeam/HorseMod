---@namespace HorseMod

local IS_CLIENT = isClient()
local IS_SERVER = isServer()
local IS_SINGLEPLAYER = not (IS_CLIENT or IS_SERVER)

---Compact wire form of a riding snapshot. Keys are single characters because
---``TableNetworkUtils`` writes every key as a full UTF string.
---@class RidingStateWire
---@field r integer Rider id
---@field a integer Animal id
---@field s integer Server state sequence
---@field x number
---@field y number
---@field z number
---@field v number Speed
---@field f integer Packed direction and gait flags

local FLAG_GALLOP = 8
local FLAG_TROT = 16
local FLAG_JUMP = 32
local FLAG_TURN = 64
local FLAG_REINS = 256
local FLAG_IDLE_TO_RUN = 512
local FLAG_LIMIT = 1024

local MAX_SPEED = 24
local MAX_COORDINATE = 100000
local MAX_VERTICAL = 32

local ridingcodec = {}

---@readonly
ridingcodec.FIELD_COUNT = 8

---@param value any
---@return boolean
---@nodiscard
local function isFiniteNumber(value)
    if type(value) ~= "number" then
        return false
    end

    return value == value and value > -math.huge and value < math.huge
end

---@param player IsoPlayer
---@return integer
---@nodiscard
function ridingcodec.encodePlayerId(player)
    if IS_SINGLEPLAYER then
        return player:getIndex()
    end

    return player:getOnlineID()
end

---@param id integer
---@return IsoPlayer?
---@nodiscard
function ridingcodec.decodePlayerId(id)
    if IS_SINGLEPLAYER then
        return getSpecificPlayer(id)
    end

    local player = getPlayerByOnlineID(id)
    if player then
        return player
    end

    -- A listen-server host holds online id 0 and can be absent from the client
    -- id map, so fall back to a scan before giving up on the snapshot.
    local players = getOnlinePlayers()
    if not players then
        return nil
    end

    for i = 0, players:size() - 1 do
        local candidate = players:get(i)
        if candidate and candidate:getOnlineID() == id then
            return candidate
        end
    end

    return nil
end

---@param dir integer
---@param gallop boolean
---@param trot boolean
---@param jump boolean
---@param turn integer
---@param hasReins boolean
---@param idleToRun boolean
---@return integer
---@nodiscard
function ridingcodec.packFlags(dir, gallop, trot, jump, turn, hasReins, idleToRun)
    local flags = dir % 8

    if gallop then
        flags = flags + FLAG_GALLOP
    end
    if trot then
        flags = flags + FLAG_TROT
    end
    if jump then
        flags = flags + FLAG_JUMP
    end
    if hasReins then
        flags = flags + FLAG_REINS
    end
    if idleToRun then
        flags = flags + FLAG_IDLE_TO_RUN
    end

    local turnCode = 1
    if turn < 0 then
        turnCode = 0
    elseif turn > 0 then
        turnCode = 2
    end

    return flags + turnCode * FLAG_TURN
end

---@param args RidingStateArguments
---@return RidingStateWire
---@nodiscard
function ridingcodec.encode(args)
    return {
        r = args.character,
        a = args.animal,
        s = args.seq,
        x = args.x,
        y = args.y,
        z = args.z,
        v = args.speed,
        f = ridingcodec.packFlags(
            args.dir,
            args.gallop,
            args.trot,
            args.jump,
            args.turn,
            args.hasReins,
            args.idleToRun
        ),
    }
end

---Rebuilds the descriptive snapshot from the wire form.
---Returns nil when any field is missing or out of range; a rejected packet must
---never be partially applied.
---@param wire RidingStateWire
---@return RidingStateArguments?
---@nodiscard
function ridingcodec.decode(wire)
    if type(wire) ~= "table" then
        return nil
    end

    if not isFiniteNumber(wire.r)
            or not isFiniteNumber(wire.a)
            or not isFiniteNumber(wire.s)
            or not isFiniteNumber(wire.x)
            or not isFiniteNumber(wire.y)
            or not isFiniteNumber(wire.z)
            or not isFiniteNumber(wire.v)
            or not isFiniteNumber(wire.f) then
        return nil
    end

    if wire.x < -MAX_COORDINATE or wire.x > MAX_COORDINATE
            or wire.y < -MAX_COORDINATE or wire.y > MAX_COORDINATE
            or wire.z < -MAX_VERTICAL or wire.z > MAX_VERTICAL then
        return nil
    end

    if wire.v < 0 or wire.v > MAX_SPEED then
        return nil
    end

    local flags = math.floor(wire.f)
    if flags ~= wire.f or flags < 0 or flags >= FLAG_LIMIT then
        return nil
    end

    local turnCode = math.floor(flags / FLAG_TURN) % 4
    if turnCode > 2 then
        return nil
    end

    local sequence = math.floor(wire.s)
    if sequence ~= wire.s or sequence < 0 then
        return nil
    end

    return {
        character = math.floor(wire.r),
        animal = math.floor(wire.a),
        seq = sequence,
        x = wire.x,
        y = wire.y,
        z = wire.z,
        dir = flags % 8,
        speed = wire.v,
        gallop = math.floor(flags / FLAG_GALLOP) % 2 == 1,
        trot = math.floor(flags / FLAG_TROT) % 2 == 1,
        jump = math.floor(flags / FLAG_JUMP) % 2 == 1,
        turn = turnCode - 1,
        hasReins = math.floor(flags / FLAG_REINS) % 2 == 1,
        idleToRun = math.floor(flags / FLAG_IDLE_TO_RUN) % 2 == 1,
    }
end

return ridingcodec
