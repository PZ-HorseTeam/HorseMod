local HorseRiding = require("HorseMod/HorseRiding")

local WALK_SPEED = 0.05      -- tiles/sec
local RUN_SPEED  = 6.0       -- tiles/sec
local DT_MAX     = 0.05      -- seconds

local ACCEL_UP   = 12.0      -- how fast we ramp up toward target
local DECEL_DOWN = 24.0      -- how fast we slow down toward target

local TURN_STEPS_PER_SEC = 14     -- how fast we rotate (steps per second)
local turnAcc = {}                -- accumulator for turn stepping
local lastTurnSign = {}           -- remembers sign when delta==180 degrees

local curSpeed = {}

local rideInit = {}

local screenVecToDir = {
    ["0,-1"]  = IsoDirections.NW,
    ["1,-1"]  = IsoDirections.N,
    ["1,0"]   = IsoDirections.NE,
    ["1,1"]   = IsoDirections.E,
    ["0,1"]   = IsoDirections.SE,
    ["-1,1"]  = IsoDirections.S,
    ["-1,0"]  = IsoDirections.SW,
    ["-1,-1"] = IsoDirections.W,
}

local idxFromDir = {
    [IsoDirections.E]  = 0,
    [IsoDirections.NE] = 1,
    [IsoDirections.N]  = 2,
    [IsoDirections.NW] = 3,
    [IsoDirections.W]  = 4,
    [IsoDirections.SW] = 5,
    [IsoDirections.S]  = 6,
    [IsoDirections.SE] = 7,
}
local dirFromIdx = {
    [0] = IsoDirections.E,  [1] = IsoDirections.NE, [2] = IsoDirections.N,  [3] = IsoDirections.NW,
    [4] = IsoDirections.W,  [5] = IsoDirections.SW, [6] = IsoDirections.S,  [7] = IsoDirections.SE,
}

local dirMove = {
    [IsoDirections.N]  = { 0,-1},
    [IsoDirections.NE] = { 1,-1},
    [IsoDirections.E]  = { 1, 0},
    [IsoDirections.SE] = { 1, 1},
    [IsoDirections.S]  = { 0, 1},
    [IsoDirections.SW] = {-1, 1},
    [IsoDirections.W]  = {-1, 0},
    [IsoDirections.NW] = {-1,-1},
}

local function getSq(x, y, z)
    return getCell():getGridSquare(math.floor(x), math.floor(y), z)
end

local function isSquareBlocked(sq)
    if not sq then return true end
    if sq:isSolid() or sq:isSolidTrans() then return true end
    return false
end

-- Is there a blocking wall between two adjacent squares?
local function blockedBetween(fromSq, toSq)
    if not fromSq or not toSq then return true end
    if fromSq == toSq then return false end
    -- check both sides
    if fromSq:isWallTo(toSq) then return true end
    if toSq:isWallTo(fromSq) then return true end
    return false
end

-- Clamp a desired move (dx,dy) so we don't cross a wall
local function collideStep(horse, dx, dy)
    if dx == 0 and dy == 0 then return 0, 0 end
    local z = horse:getZ()
    local x0, y0 = horse:getX(), horse:getY()
    local x1, y1 = x0 + dx, y0 + dy

    local fx, fy = math.floor(x0), math.floor(y0)
    local tx, ty = math.floor(x1), math.floor(y1)

    local fromSq = getSq(x0, y0, z)
    local toSq   = getSq(x1, y1, z)

    if isSquareBlocked(toSq) then
        local xOnlySq = getSq(x1, y0, z)
        local yOnlySq = getSq(x0, y1, z)
        local canX = not isSquareBlocked(xOnlySq)
        local canY = not isSquareBlocked(yOnlySq)
        if canX and not canY then return dx, 0 end
        if canY and not canX then return 0, dy end
        if canX and canY then
        if math.abs(dx) > math.abs(dy) then return dx, 0 else return 0, dy end
        end
        return 0, 0
    end

    -- check the edge between the current square and the mid square
    local bx, by = dx, dy
    if tx ~= fx then
        -- moving across a vertical boundary: use the square at (tx, fy)
        local midSqX = getSq(tx, fy, z)
        if blockedBetween(fromSq, midSqX) then bx = 0 end
    end
    if ty ~= fy then
        -- moving across a horizontal boundary: use the square at (fx, ty)
        local midSqY = getSq(fx, ty, z)
        if blockedBetween(fromSq, midSqY) then by = 0 end
    end

    -- If both got blocked, stop. Otherwise slide on the free axis
    if bx == 0 and by == 0 then return 0, 0 end
    return bx, by
end

local function moveWithCollision(horse, vx, vy, dt)
    -- Split frame distance into substeps to avoid going through walls
    local remaining = dt
    while remaining > 0 do
        local s = math.min(remaining, 0.28)  -- seconds of travel per substep
        local dx, dy = vx * s, vy * s
        dx, dy = collideStep(horse, dx, dy)
        if dx == 0 and dy == 0 then return end
        horse:setX(horse:getX() + dx)
        horse:setY(horse:getY() + dy)
        remaining = remaining - s
    end
end

local function readInput()
    local core = getCore()
    local sx, sy = 0, 0
    if isKeyDown(core:getKey("Forward"))  then sy = sy - 1 end
    if isKeyDown(core:getKey("Backward")) then sy = sy + 1 end
    if isKeyDown(core:getKey("Left"))     then sx = sx - 1 end
    if isKeyDown(core:getKey("Right"))    then sx = sx + 1 end
    local run = isKeyDown(core:getKey("Run")) or isKeyDown(core:getKey("Sprint"))
    return sx, sy, run
end

-- helper to ease current -> target by at most rate*dt
local function approach(current, target, rate, dt)
    local delta = target - current
    if delta > 0 then
        local step = math.min(delta, rate * dt)
        return current + step
    else
        local step = math.max(delta, -rate * dt)
        return current + step
    end
end

Events.OnPlayerUpdate.Add(function(player)
    if not player then return end
    local horse = HorseRiding.getMountedHorse and HorseRiding.getMountedHorse(player)
    if not horse or not horse:isExistInTheWorld() then return end
    if player:getVariableString("RidingHorse") ~= "true" then return end
    local id = player:getPlayerNum()
    if not rideInit[id] then
        if horse.stopAllMovementNow then horse:stopAllMovementNow() end
        if horse.getPathFindBehavior2 then horse:getPathFindBehavior2():reset() end
        if horse.setVariable then horse:setVariable("bPathfind", false) end
        rideInit[id] = true
    end

    if horse.getPathFindBehavior2 then horse:getPathFindBehavior2():reset() end
    if horse.getBehavior then horse:getBehavior():setBlockMovement(true) end

    local dt = math.min(GameTime.getInstance():getTimeDelta(), DT_MAX)

    local sx, sy, run = readInput()
    local moving = (sx ~= 0 or sy ~= 0)

    -- desired facing from input (or keep current if no input)
    local desiredDir = moving and screenVecToDir[tostring(sx)..","..tostring(sy)] or horse:getDir()

    -- Stepped turning for horse & player (so they don't desync the direction when turning 180)
    turnAcc[id] = (turnAcc[id] or 0) + dt * TURN_STEPS_PER_SEC

    local curDir = horse:getDir()
    local ci = idxFromDir[curDir] or 0
    local ti = idxFromDir[desiredDir] or ci

    local d = (ti - ci) % 8
    if d > 4 then d = d - 8 end

    -- choose a consistent sign, for exact 180, reuse last sign (default clockwise)
    local sign
    if d == 0 then
        sign = 0
    elseif d == 4 or d == -4 then
        sign = lastTurnSign[id] or 1
    else
        sign = (d > 0) and 1 or -1
    end

    -- at most one step per accumulated tick
    while turnAcc[id] >= 1 and d ~= 0 do
        ci = (ci + sign) % 8
        d = (ti - ci) % 8
        if d > 4 then d = d - 8 end
        turnAcc[id] = turnAcc[id] - 1
    end

    local facedDir = dirFromIdx[ci] or desiredDir
    lastTurnSign[id] = (sign ~= 0) and sign or lastTurnSign[id]

    -- set both to the same stepped direction
    horse:setDir(facedDir)
    player:setDir(facedDir)

    -- acceleration
    local current = curSpeed[id] or 0.0
    local target  = (moving and (run and RUN_SPEED or WALK_SPEED)) or 0.0
    local rate    = (target > current) and ACCEL_UP or DECEL_DOWN
    current = approach(current, target, rate, dt)
    if current < 0.0001 then current = 0 end
    curSpeed[id] = current

    local d2 = (ti - ci) % 8
    if d2 > 4 then d2 = d2 - 8 end

    local walkingTurn = player:getVariableBoolean("isTurning")
    if walkingTurn then
        -- sign > 0 -> CCW (left), sign < 0 -> CW (right)
        -- horse:setVariable("animalWalkingLeft",  (sign > 0))
        horse:setVariable("animalWalkingRight", walkingTurn)
        print("Walking left or right")
    else
        horse:setVariable("animalWalkingLeft",  false)
        horse:setVariable("animalWalkingRight", false)
    end

    -- Move along the stepped facing so visuals and travel match
    if moving and current > 0 then
        local v = dirMove[facedDir]

        local len = ((v[1] ~= 0) and (v[2] ~= 0)) and math.sqrt(2) or 1
        local speed = current / len
        -- velocity components (tiles/sec) in grid space
        local vx, vy = v[1] * speed, v[2] * speed
        -- move with collision substeps
        moveWithCollision(horse, vx, vy, dt)

        horse:setVariable("bPathfind", true)
        horse:setVariable("animalWalking", not run)
        horse:setVariable("animalRunning", run)
    else
        horse:setVariable("bPathfind", false)
        horse:setVariable("animalRunning", false)
        horse:setVariable("animalWalking", false)
    end

    if horse:getVariableBoolean("HorseGallop") then
        player:setVariable("HorseGallop", true)
    elseif not player:getVariableBoolean("HorseGallop") then
        player:setVariable("HorseGallop", false)
    end

    player:setX(horse:getX())
    player:setY(horse:getY())
    player:setZ(horse:getZ())
    player:setVariable("mounted", true)
end)

function HorseRiding._clearRideCache(pid)
    curSpeed[pid]     = nil
    turnAcc[pid]      = nil
    lastTurnSign[pid] = nil
    rideInit[pid]     = nil
end