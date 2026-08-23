---@namespace HorseMod

---Approximation of the engine relevance test used by ``UdpConnection.isRelevantTo``.
---The real test is not reachable from Lua, so riders route their own snapshots.
local relevance = {}

---@readonly
relevance.MIN_CHUNK_GRID_WIDTH = 12

---@readonly
relevance.MAX_CHUNK_GRID_WIDTH = 20

---@readonly
relevance.MIN_RANGE_TILES = 64

---@readonly
relevance.MAX_RANGE_TILES = 96

---Mirrors ``GameServer.receivePlayerConnect``: the connection range is
---``clamp(chunkGridWidth, 12, 20) / 2 + 2`` chunks, and a chunk is eight tiles.
---@param chunkGridWidth number
---@return integer rangeTiles
---@nodiscard
function relevance.chunkGridWidthToRangeTiles(chunkGridWidth)
    local width = math.floor(chunkGridWidth)
    if width < relevance.MIN_CHUNK_GRID_WIDTH then
        width = relevance.MIN_CHUNK_GRID_WIDTH
    elseif width > relevance.MAX_CHUNK_GRID_WIDTH then
        width = relevance.MAX_CHUNK_GRID_WIDTH
    end

    return (math.floor(width / 2) + 2) * 8
end

---Converts a reported chunk grid width into a range the server is willing to trust.
---Anything missing or malformed falls back to the widest range so a client can
---never shrink its own relevance area to hide riders.
---@param reportedWidth any
---@return integer rangeTiles
---@nodiscard
function relevance.sanitizeReportedWidth(reportedWidth)
    if type(reportedWidth) ~= "number" then
        return relevance.MAX_RANGE_TILES
    end

    if reportedWidth ~= reportedWidth or reportedWidth <= 0 then
        return relevance.MAX_RANGE_TILES
    end

    local rangeTiles = relevance.chunkGridWidthToRangeTiles(reportedWidth)
    if rangeTiles < relevance.MIN_RANGE_TILES then
        return relevance.MIN_RANGE_TILES
    elseif rangeTiles > relevance.MAX_RANGE_TILES then
        return relevance.MAX_RANGE_TILES
    end

    return rangeTiles
end

---Mirrors ``IsoChunkMap.CalcChunkWidth`` so a client can report the same grid
---width the engine sent in its connect packet. Debug chunk-map overrides are not
---visible here, and they only ever shrink the grid, so over-reporting is safe.
---@return integer chunkGridWidth
---@nodiscard
function relevance.getLocalChunkGridWidth()
    local core = getCore()
    local del = math.max(core:getScreenWidth() / 1920, core:getScreenHeight() / 1080)
    if del > 1 then
        del = 1
    end

    local width = math.floor(13 * del * 1.5)
    if math.floor(width / 2) * 2 == width then
        width = width + 1
    end

    if width > 19 then
        width = 19
    end

    return width
end

---Axis-aligned test matching the shape of the engine relevance rectangle.
---@param x number
---@param y number
---@param observerX number
---@param observerY number
---@param rangeTiles number
---@return boolean
---@nodiscard
function relevance.isInRange(x, y, observerX, observerY, rangeTiles)
    local dx = observerX - x
    if dx < 0 then
        dx = -dx
    end
    if dx > rangeTiles then
        return false
    end

    local dy = observerY - y
    if dy < 0 then
        dy = -dy
    end

    return dy <= rangeTiles
end

return relevance
