---@namespace HorseMod

---Holds riding snapshots whose rider or animal has not streamed in yet.
---The relevance approximation on the server cannot see the engine's real
---connect areas, so a snapshot can legitimately arrive a moment early.
local PendingRidingState = {}

local MAX_ENTRIES = 32
local EXPIRY_MS = 3000

---@class PendingRidingEntry
---@field args RidingStateArguments
---@field stamp integer

---@type table<string, PendingRidingEntry>
local pending = {}
local pendingCount = 0

---@param args RidingStateArguments
---@return string
---@nodiscard
local function makeKey(args)
    return args.character .. ":" .. args.animal
end

local function dropOldest()
    local oldestKey = nil
    local oldestStamp = nil

    for key, entry in pairs(pending) do
        if not oldestStamp or entry.stamp < oldestStamp then
            oldestStamp = entry.stamp
            oldestKey = key
        end
    end

    if oldestKey then
        pending[oldestKey] = nil
        pendingCount = pendingCount - 1
    end
end

---@param args RidingStateArguments
function PendingRidingState.store(args)
    local key = makeKey(args)
    local entry = pending[key]

    if entry then
        if args.seq < entry.args.seq then
            return
        end
        entry.args = args
        entry.stamp = getTimestampMs()
        return
    end

    if pendingCount >= MAX_ENTRIES then
        dropOldest()
    end

    pending[key] = {
        args = args,
        stamp = getTimestampMs(),
    }
    pendingCount = pendingCount + 1
end

---@param character integer
---@param animal integer
function PendingRidingState.clear(character, animal)
    local key = character .. ":" .. animal
    if pending[key] then
        pending[key] = nil
        pendingCount = pendingCount - 1
    end
end

function PendingRidingState.clearAll()
    pending = {}
    pendingCount = 0
end

---Retries every held snapshot. The resolver returns true once it has applied
---the snapshot, which retires the entry.
---@param resolve fun(args: RidingStateArguments): boolean
function PendingRidingState.flush(resolve)
    if pendingCount == 0 then
        return
    end

    local now = getTimestampMs()
    for key, entry in pairs(pending) do
        if now - entry.stamp > EXPIRY_MS then
            pending[key] = nil
            pendingCount = pendingCount - 1
        elseif resolve(entry.args) then
            pending[key] = nil
            pendingCount = pendingCount - 1
        end
    end
end

---@return integer
---@nodiscard
function PendingRidingState.getCount()
    return pendingCount
end

return PendingRidingState
