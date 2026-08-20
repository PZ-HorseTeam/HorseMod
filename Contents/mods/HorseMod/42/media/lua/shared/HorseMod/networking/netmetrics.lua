---@namespace HorseMod

---@class NetCommandMetric
---@field name string
---@field id integer
---@field sends integer
---@field targeted integer
---@field broadcasts integer
---@field argBytes integer
---@field envelopeBytes integer

---@class NetMetricsSnapshot
---@field elapsed number
---@field commands NetCommandMetric[]
---@field counters table<string, integer>
---@field totalSends integer
---@field totalBytes integer
---@field sendsPerSecond number
---@field bytesPerSecond number

local PACKET_HEADER_BYTES = 3
local BOOLEAN_FLAG_BYTES = 1
local STRING_OVERHEAD_BYTES = 3
local NUMBER_BYTES = 9
local BOOLEAN_BYTES = 2
local TABLE_COUNT_BYTES = 4
local MODULE_BYTES = STRING_OVERHEAD_BYTES + 8

local netmetrics = {}

---Set to true to start estimating traffic. Every hot-path call site must test
---this field before doing any work; nothing here is free once it is on.
netmetrics.enabled = false

---@type table<integer, NetCommandMetric>
local commandMetrics = {}

---@type table<string, integer>
local counters = {}

local windowStart = 0
local totalSends = 0
local totalBytes = 0

---@param value any
---@return integer
---@nodiscard
local function estimateValueBytes(value)
    local valueType = type(value)
    if valueType == "number" then
        return NUMBER_BYTES
    elseif valueType == "boolean" then
        return BOOLEAN_BYTES
    elseif valueType == "string" then
        return STRING_OVERHEAD_BYTES + #value
    elseif valueType == "table" then
        local bytes = 1 + TABLE_COUNT_BYTES
        for key, nested in pairs(value) do
            bytes = bytes + estimateValueBytes(key) + estimateValueBytes(nested)
        end
        return bytes
    end

    return 0
end

---Estimated payload bytes for a command argument table.
---This mirrors TableNetworkUtils.save and is not a measured socket byte count.
---@param args table?
---@return integer
---@nodiscard
function netmetrics.estimateArgBytes(args)
    if not args then
        return 0
    end

    local bytes = TABLE_COUNT_BYTES
    for key, value in pairs(args) do
        local valueBytes = estimateValueBytes(value)
        if valueBytes > 0 then
            bytes = bytes + estimateValueBytes(key) + valueBytes
        end
    end

    return bytes
end

---@param commandId integer
---@return integer
---@nodiscard
local function estimateEnvelopeBytes(commandId)
    local idLength = 1
    if commandId >= 100 then
        idLength = 3
    elseif commandId >= 10 then
        idLength = 2
    end

    return PACKET_HEADER_BYTES + MODULE_BYTES + STRING_OVERHEAD_BYTES + idLength + BOOLEAN_FLAG_BYTES
end

---@param name string
---@param id integer
---@return NetCommandMetric
---@nodiscard
local function getCommandMetric(name, id)
    local metric = commandMetrics[id]
    if metric then
        return metric
    end

    metric = {
        name = name,
        id = id,
        sends = 0,
        targeted = 0,
        broadcasts = 0,
        argBytes = 0,
        envelopeBytes = 0,
    }
    commandMetrics[id] = metric

    return metric
end

---@param name string
---@param id integer
---@param isTargeted boolean
---@param args table?
function netmetrics.recordSend(name, id, isTargeted, args)
    local metric = getCommandMetric(name, id)
    local argBytes = netmetrics.estimateArgBytes(args)
    local envelopeBytes = estimateEnvelopeBytes(id)

    metric.sends = metric.sends + 1
    if isTargeted then
        metric.targeted = metric.targeted + 1
    else
        metric.broadcasts = metric.broadcasts + 1
    end
    metric.argBytes = metric.argBytes + argBytes
    metric.envelopeBytes = metric.envelopeBytes + envelopeBytes

    totalSends = totalSends + 1
    totalBytes = totalBytes + argBytes + envelopeBytes
end

---@param key string
---@param amount integer?
function netmetrics.count(key, amount)
    local delta = amount
    if not delta then
        delta = 1
    end

    local current = counters[key]
    if not current then
        current = 0
    end
    counters[key] = current + delta
end

function netmetrics.reset()
    commandMetrics = {}
    counters = {}
    totalSends = 0
    totalBytes = 0
    windowStart = getTimestampMs()
end

---@param enable boolean
function netmetrics.setEnabled(enable)
    netmetrics.enabled = enable == true
    netmetrics.reset()
end

---@return NetMetricsSnapshot
---@nodiscard
function netmetrics.snapshot()
    local elapsed = (getTimestampMs() - windowStart) / 1000
    if elapsed <= 0 then
        elapsed = 0.001
    end

    ---@type NetCommandMetric[]
    local commandList = {}
    for _, metric in pairs(commandMetrics) do
        commandList[#commandList + 1] = metric
    end

    ---@type table<string, integer>
    local counterCopy = {}
    for key, value in pairs(counters) do
        counterCopy[key] = value
    end

    return {
        elapsed = elapsed,
        commands = commandList,
        counters = counterCopy,
        totalSends = totalSends,
        totalBytes = totalBytes,
        sendsPerSecond = totalSends / elapsed,
        bytesPerSecond = totalBytes / elapsed,
    }
end

function netmetrics.dump()
    local snapshot = netmetrics.snapshot()
    DebugLog.log(string.format(
        "[HorseMod] [NetMetrics] window=%.1fs sends=%d estimatedPayloadBytes=%d sends/s=%.1f estimatedBytes/s=%.0f",
        snapshot.elapsed,
        snapshot.totalSends,
        snapshot.totalBytes,
        snapshot.sendsPerSecond,
        snapshot.bytesPerSecond
    ))

    for i = 1, #snapshot.commands do
        local metric = snapshot.commands[i]
        DebugLog.log(string.format(
            "[HorseMod] [NetMetrics] %s id=%d sends=%d targeted=%d broadcasts=%d args=%dB envelope=%dB",
            metric.name,
            metric.id,
            metric.sends,
            metric.targeted,
            metric.broadcasts,
            metric.argBytes,
            metric.envelopeBytes
        ))
    end

    for key, value in pairs(snapshot.counters) do
        DebugLog.log(string.format("[HorseMod] [NetMetrics] counter %s=%d", key, value))
    end
end

netmetrics.reset()

HorseModNetMetrics = netmetrics

return netmetrics
