local HorseRiding = require("HorseMod/shared/HorseMod_Riding")
local Stamina = require("HorseMod/HorseMod_Stamina")


local WALK_SPEED = 0.05      -- tiles/sec
local RUN_SPEED  = 4.0       -- tiles/sec
local DT_MAX     = 0.005      -- seconds

local ACCEL_UP   = 12.0
local DECEL_DOWN = 36.0

local TURN_STEPS_PER_SEC = 14
local turnAcc, lastTurnSign, prevFacedDir = {}, {}, {}
local curSpeed, rideInit = {}, {}

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
    [IsoDirections.E]  = 0, [IsoDirections.NE] = 1, [IsoDirections.N]  = 2, [IsoDirections.NW] = 3,
    [IsoDirections.W]  = 4, [IsoDirections.SW] = 5, [IsoDirections.S]  = 6, [IsoDirections.SE] = 7,
}
local dirFromIdx = {
    [0] = IsoDirections.E, [1] = IsoDirections.NE, [2] = IsoDirections.N, [3] = IsoDirections.NW,
    [4] = IsoDirections.W, [5] = IsoDirections.SW, [6] = IsoDirections.S, [7] = IsoDirections.SE,
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

function GetSpeeds()
    local options = PZAPI.ModOptions:getOptions("HorseMod")
    if not options then return 1.0 end
    local walk = options:getOption("HorseWalkSpeed"):getValue()
    local gallop = options:getOption("HorseGallopSpeed"):getValue()
    if walk and gallop then return walk, gallop end
    return 1.0
end

local function getSq(x,y,z) return getCell():getGridSquare(math.floor(x), math.floor(y), z) end

-- CENTER blockers only (no WallN/WallW/Window* here!)
local function squareCenterSolid(sq)
    if not sq then return true end
    if sq:isSolid() or sq:isSolidTrans() then return true end
    local objs = sq:getObjects()
    if objs then
        for i=0, objs:size()-1 do
            local o = objs:get(i)
            if o and o.getProperties then
                local p = o:getProperties()
                if p and p.Is then
                    if p:Is("Solid") or p:Is("SolidTrans") then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function edgeHoppableBetween(a, b)
    if not a or not b then return nil end
    local ax, ay = a:getX(), a:getY()
    local bx, by = b:getX(), b:getY()

    if bx == ax + 1 and by == ay then
        -- moving EAST: use west edge of destination
        return b:getHoppable(false)
    elseif bx == ax - 1 and by == ay then
        -- moving WEST: use west edge of origin
        return a:getHoppable(false)
    elseif by == ay + 1 and bx == ax then
        -- moving SOUTH: use north edge of destination
        return b:getHoppable(true)
    elseif by == ay - 1 and bx == ax then
        -- moving NORTH: use north edge of origin
        return a:getHoppable(true)
    end
    return nil
end

-- Edge blockers (walls/windows/doors/fences)
local function blockedBetween(fromSq, toSq, horse)
    if not fromSq or not toSq then return true end
    if fromSq == toSq then return false end

    -- FENCE
    local hop = edgeHoppableBetween(fromSq, toSq)
    if hop and hop.isHoppable and hop:isHoppable() then
        if horse and horse:getVariableBoolean("HorseJump") then
            return false
        else
            return true
        end
    end

    -- Walls / windows / closed doors
    if fromSq:isWallTo(toSq) or toSq:isWallTo(fromSq) then return true end
    if fromSq:isWindowTo(toSq) or toSq:isWindowTo(fromSq) then return true end
    local door = fromSq:getDoorTo(toSq); if door and not door:IsOpen() then return true end
    door = toSq:getDoorTo(fromSq); if door and not door:IsOpen() then return true end

    return false
end

-- crossing helper: edge must be open and destination center must be free
local function canCross(fx, fy, tx, ty, z, horse)
    local a = getSq(fx, fy, z)
    local b = getSq(tx, ty, z)
    if blockedBetween(a, b, horse) then return false end
    if squareCenterSolid(b) then return false end
    return true
end

local EDGE_PAD = 0.01
local function signf(v) return (v < 0) and -1 or ((v > 0) and 1 or 0) end

local function collideStepAt(horse, z, x0, y0, dx, dy)
    if dx == 0 and dy == 0 then return 0, 0 end

    local ox, oy = dx, dy
    local stepLen = math.sqrt(ox*ox + oy*oy)

    local fx, fy = math.floor(x0), math.floor(y0)
    local rx, ry = dx, dy

    -- clamp vs vertical edges (X)
    if rx > 0 then
        if not canCross(fx, fy, fx+1, fy, z, horse) then
            local boundary = fx + 1 - EDGE_PAD
            if x0 + rx > boundary then rx = math.max(0, boundary - x0) end
        end
    elseif rx < 0 then
        if not canCross(fx-1, fy, fx, fy, z, horse) then
            local boundary = fx + EDGE_PAD
            if x0 + rx < boundary then rx = math.min(0, boundary - x0) end
        end
    end

    -- clamp vs horizontal edges (Y)
    if ry > 0 then
        if not canCross(fx, fy, fx, fy+1, z, horse) then
            local boundary = fy + 1 - EDGE_PAD
            if y0 + ry > boundary then ry = math.max(0, boundary - y0) end
        end
    elseif ry < 0 then
        if not canCross(fx, fy-1, fx, fy, z, horse) then
            local boundary = fy + EDGE_PAD
            if y0 + ry < boundary then ry = math.min(0, boundary - y0) end
        end
    end
    if rx == 0 and ry == 0 then return 0, 0 end

    local function centerBlocked(nx, ny)
        return squareCenterSolid(getSq(nx, ny, z))
    end

    -- destination center check
    local x1, y1 = x0 + rx, y0 + ry
    if centerBlocked(x1, y1) then
        local tryXFirst = math.abs(rx) >= math.abs(ry)
        local function tryProjectX()
            local px = signf(ox) * stepLen
            if px > 0 then
                if not canCross(fx, fy, fx+1, fy, z, horse) then
                    local b = fx + 1 - EDGE_PAD
                    if x0 + px > b then px = math.max(0, b - x0) end
                end
            elseif px < 0 then
                if not canCross(fx-1, fy, fx, fy, z, horse) then
                    local b = fx + EDGE_PAD
                    if x0 + px < b then px = math.min(0, b - x0) end
                end
            end
            if px ~= 0 and not centerBlocked(x0 + px, y0) then return px, 0 end
            return 0, 0
        end
        local function tryProjectY()
            local py = signf(oy) * stepLen
            if py > 0 then
                if not canCross(fx, fy, fx, fy+1, z, horse) then
                    local b = fy + 1 - EDGE_PAD
                    if y0 + py > b then py = math.max(0, b - y0) end
                end
            elseif py < 0 then
                if not canCross(fx, fy-1, fx, fy, z, horse) then
                    local b = fy + EDGE_PAD
                    if y0 + py < b then py = math.min(0, b - y0) end
                end
            end
            if py ~= 0 and not centerBlocked(x0, y0 + py) then return 0, py end
            return 0, 0
        end
        if tryXFirst then
            rx, ry = tryProjectX(); if rx == 0 and ry == 0 then rx, ry = tryProjectY() end
        else
            rx, ry = tryProjectY(); if rx == 0 and ry == 0 then rx, ry = tryProjectX() end
        end
        if rx == 0 and ry == 0 then return 0, 0 end
        x1, y1 = x0 + rx, y0 + ry
    end

    -- mid-square checks
    local tx, ty = math.floor(x1), math.floor(y1)
    local midSqX = (tx ~= fx) and getSq(tx, fy, z) or nil
    local midSqY = (ty ~= fy) and getSq(fx, ty, z) or nil
    local killedX, killedY = false, false
    if midSqX and squareCenterSolid(midSqX) then rx = 0; killedX = true end
    if midSqY and squareCenterSolid(midSqY) then ry = 0; killedY = true end

    -- axis projection if one axis killed
    if killedX and not killedY and ry ~= 0 then
        local py = signf(oy) * stepLen
        if py > 0 then
            if not canCross(fx, fy, fx, fy+1, z, horse) then
                local b = fy + 1 - EDGE_PAD
                if y0 + py > b then py = math.max(0, b - y0) end
            end
        elseif py < 0 then
            if not canCross(fx, fy-1, fx, fy, z, horse) then
                local b = fy + EDGE_PAD
                if y0 + py < b then py = math.min(0, b - y0) end
            end
        end
        if py ~= 0 and not centerBlocked(x0, y0 + py) then return 0, py else return 0, 0 end
    elseif killedY and not killedX and rx ~= 0 then
        local px = signf(ox) * stepLen
        if px > 0 then
            if not canCross(fx, fy, fx+1, fy, z, horse) then
                local b = fx + 1 - EDGE_PAD
                if x0 + px > b then px = math.max(0, b - x0) end
            end
        elseif px < 0 then
            if not canCross(fx-1, fy, fx, fy, z, horse) then
                local b = fx + EDGE_PAD
                if x0 + px < b then px = math.min(0, b - x0) end
            end
        end
        if px ~= 0 and not centerBlocked(x0 + px, y0) then return px, 0 else return 0, 0 end
    end
    if rx == 0 and ry == 0 then return 0, 0 end

    -- diagonal corner rule
    if (tx ~= fx) and (ty ~= fy) and (rx ~= 0) and (ry ~= 0) then
        local xFirstOk = (not midSqX or not squareCenterSolid(midSqX))
                      and canCross(fx, fy, tx, fy, z, horse)
                      and canCross(tx, fy, tx, ty, z, horse)
        local yFirstOk = (not midSqY or not squareCenterSolid(midSqY))
                      and canCross(fx, fy, fx, ty, z, horse)
                      and canCross(fx, ty, tx, ty, z, horse)
        if not xFirstOk and not yFirstOk then
            -- project onto best axis
            local px, py = signf(ox) * stepLen, signf(oy) * stepLen
            local rx1, ry1 = px, 0
            if rx1 > 0 then
                if not canCross(fx, fy, fx+1, fy, z, horse) then
                    local b = fx + 1 - EDGE_PAD
                    if x0 + rx1 > b then rx1 = math.max(0, b - x0) end
                end
            elseif rx1 < 0 then
                if not canCross(fx-1, fy, fx, fy, z, horse) then
                    local b = fx + EDGE_PAD
                    if x0 + rx1 < b then rx1 = math.min(0, b - x0) end
                end
            end
            local okX = (rx1 ~= 0) and not squareCenterSolid(getSq(x0 + rx1, y0, z))

            local rx2, ry2 = 0, py
            if ry2 > 0 then
                if not canCross(fx, fy, fx, fy+1, z, horse) then
                    local b = fy + 1 - EDGE_PAD
                    if y0 + ry2 > b then ry2 = math.max(0, b - y0) end
                end
            elseif ry2 < 0 then
                if not canCross(fx, fy-1, fx, fy, z, horse) then
                    local b = fy + EDGE_PAD
                    if y0 + ry2 < b then ry2 = math.min(0, b - y0) end
                end
            end
            local okY = (ry2 ~= 0) and not squareCenterSolid(getSq(x0, y0 + ry2, z))

            if okX and not okY then return rx1, 0 end
            if okY and not okX then return 0, ry2 end
            if okX and okY then
                if math.abs(ox) >= math.abs(oy) then return rx1, 0 else return 0, ry2 end
            end
            return 0, 0
        end
    end

    return rx, ry
end

-- Do all substeps in locals; write back ONCE.
local function moveWithCollision(horse, vx, vy, dt)
    local z = horse:getZ()
    local x = horse:getX()
    local y = horse:getY()

    local remaining = dt
    local maxVel = math.max(math.abs(vx), math.abs(vy))
    if maxVel == 0 then return end

    local maxStepDist = 0.065  -- keep your precision, but only one final write

    while remaining > 0 do
        local s = math.min(remaining, maxStepDist / maxVel)
        local dx, dy = vx * s, vy * s

        local rx, ry = collideStepAt(horse, z, x, y, dx, dy)
        if rx == 0 and ry == 0 then break end

        local nx, ny = x + rx, y + ry
        if squareCenterSolid(getSq(nx, ny, z)) then break end

        x, y = nx, ny
        remaining = remaining - s
    end

    -- Single commit per frame
    if x ~= horse:getX() or y ~= horse:getY() then
        horse:setX(x); horse:setY(y)
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

local function approach(current, target, rate, dt)
    local delta = target - current
    if delta > 0 then
        local step = math.min(delta, rate * dt); return current + step
    else
        local step = math.max(delta, -rate * dt); return current + step
    end
end

local function dirToUnitXY(dir)
    local v = dirMove[dir]
    if not v then return 1, 0 end
    local x, y = v[1], v[2]
    if x ~= 0 and y ~= 0 then
        local inv = 1 / math.sqrt(2)
        return x * inv, y * inv
    end
    return x, y
end

local function resetFacingAnim(char, isoDir)
    if not (char and char.setTargetAndCurrentDirection) then return end
    local x, y = dirToUnitXY(isoDir)
    char:setTargetAndCurrentDirection(x, y)
end

local pending180, startDir180, goalDir180 = {}, {}, {}

local function dirDist4(a, b)
    local ia, ib = idxFromDir[a] or 0, idxFromDir[b] or 0
    local d = (ib - ia) % 8
    if d > 4 then d = 8 - d end
    return d
end

Events.OnPlayerUpdate.Add(function(player)
    if not player then return end
    local horse = HorseRiding.getMountedHorse and HorseRiding.getMountedHorse(player)
    if not horse or not horse:isExistInTheWorld() then return end
    if player:getVariableString("RidingHorse") ~= "true" then return end
    player:setSneaking(true)

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

    local trotting = horse:getVariableBoolean("HorseTrot") == true
    local stamBefore = Stamina.get(horse)
    local dtStam = dt

    -- Drain / regen
    if moving and run then
        Stamina.modify(horse, -Stamina.DRAIN_RUN * dtStam, true)
    elseif moving and trotting then
        Stamina.modify(horse,  Stamina.REGEN_TROT * dtStam, true)
    elseif moving then
        Stamina.modify(horse,  Stamina.REGEN_WALK * dtStam, true)
    else
        Stamina.modify(horse,  Stamina.REGEN_IDLE * dtStam, true)
    end

    -- Prevent running at zero stamina
    if not Stamina.canRun(horse) then
        run = false
    end

    local desiredDir = moving and screenVecToDir[tostring(sx)..","..tostring(sy)] or horse:getDir()

    turnAcc[id] = (turnAcc[id] or 0) + dt * TURN_STEPS_PER_SEC

    local curDir = horse:getDir()
    local ci = idxFromDir[curDir] or 0
    local ti = idxFromDir[desiredDir] or ci

    local d_mod = (ti - ci) % 8
    local d_pre = (d_mod > 4) and (d_mod - 8) or d_mod

    if not pending180[id] and dirDist4(curDir, desiredDir) == 4 then
        pending180[id]  = true
        startDir180[id] = curDir
        goalDir180[id]  = desiredDir
        -- one-time twist flush at the beginning of the 180
        resetFacingAnim(horse, startDir180[id])
        resetFacingAnim(player, startDir180[id])
    end

    -- choose turn sign (sticky for exactly 180°)
    local sign
    if d_pre == 0 then
        sign = 0
    elseif math.abs(d_pre) == 4 then
        sign = lastTurnSign[id] or 1
    else
        sign = (d_pre > 0) and 1 or -1
    end

    -- step the direction (at most one step per chunk)
    while turnAcc[id] >= 1 and d_pre ~= 0 do
        ci = (ci + sign) % 8
        d_mod = (ti - ci) % 8
        d_pre = (d_mod > 4) and (d_mod - 8) or d_mod
        turnAcc[id] = turnAcc[id] - 1
    end

    local facedDir = dirFromIdx[ci] or desiredDir
    lastTurnSign[id] = (sign ~= 0) and sign or lastTurnSign[id]

    -- lock both to the same stepped direction
    horse:setDir(facedDir)
    player:setDir(facedDir)

    -- 180° TURN COMPLETE or CANCELED: clear pending without extra resets
    if pending180[id] then
        if facedDir == goalDir180[id] then
            -- finished the planned 180°; nothing else to do
            pending180[id], startDir180[id], goalDir180[id] = false, nil, nil
        else
            -- if input deviates from 180° path, cancel the pending flag
            local dist = dirDist4(facedDir, goalDir180[id])
            if dist ~= 4 and dist ~= 0 then
                pending180[id], startDir180[id], goalDir180[id] = false, nil, nil
            end
        end
    end

    local walkMul, gallopMul = GetSpeeds()
    local geneSpeed = horse:getVariableString("geneSpeed") or 1.0
    walkMul   = walkMul   * geneSpeed
    gallopMul = gallopMul * geneSpeed

    -- If we're trying to run, scale run speed by stamina curve below 50%
    if run then
        local f = Stamina.runSpeedFactor(horse)
        gallopMul = gallopMul * f
    end

    horse:setVariable("HorseWalkSpeed", walkMul)
    horse:setVariable("HorseRunSpeed",  gallopMul)

    -- speed/locomotion
    local current = curSpeed[id] or 0.0
    local target  = (moving and (run and RUN_SPEED * gallopMul or WALK_SPEED * walkMul)) or 0.0
    local rate    = (target > current) and ACCEL_UP or DECEL_DOWN
    current = approach(current, target, rate, dt)
    if current < 0.0001 then current = 0 end
    curSpeed[id] = current

    if moving and current > 0 then
        local v = dirMove[facedDir]
        local len = ((v[1] ~= 0) and (v[2] ~= 0)) and math.sqrt(2) or 1
        local speed = current / len
        local vx, vy = v[1] * speed, v[2] * speed
        moveWithCollision(horse, vx, vy, dt)

        horse:setVariable("bPathfind", true)
        horse:setVariable("animalWalking", not run)
        horse:setVariable("HorseGallop", run)
    else
        horse:setVariable("bPathfind", false)
        horse:setVariable("HorseGallop", false)
        horse:setVariable("animalWalking", false)
    end

    -- if moving and current > 0 then
    --     local v = dirMove[facedDir]
    --     local len = ((v[1] ~= 0) and (v[2] ~= 0)) and math.sqrt(2) or 1
    --     local speed = current / len
    --     local vx, vy = v[1] * speed, v[2] * speed

    --     moveWithCollision(horse, vx, vy, dt)

    --     horse:setVariable("bPathfind", true)
    --     horse:setVariable("animalWalking", not run)
    --     horse:setVariable("HorseGallop", run)
    -- else
    --     horse:setVariable("bPathfind", false)
    --     horse:setVariable("HorseGallop", false)
    --     horse:setVariable("animalWalking", false)
    -- end

    local mirrorVars = { "HorseGallop","isTurningLeft","isTurningRight","isTurningLeftSharp","isTurningRightSharp" }
    for i = 1, #mirrorVars do
        local k = mirrorVars[i]
        local v = horse:getVariableBoolean(k)
        if player:getVariableBoolean(k) ~= v then player:setVariable(k, v) end
    end

    player:setX(horse:getX()); player:setY(horse:getY()); player:setZ(horse:getZ())
    player:setVariable("mounted", true)
    UpdateHorseAudio(player)
end)

function HorseRiding._clearRideCache(pid)
    curSpeed[pid] = nil
    turnAcc[pid] = nil
    lastTurnSign[pid] = nil
    rideInit[pid] = nil
    pending180[pid] = nil
    startDir180[pid] = nil
    goalDir180[pid] = nil
end

-- local recipe = ScriptManager.instance:getCraftRecipe("SliceHead")
-- if recipe then
--     local outputs = recipe:getOutputs()
--     for i=0, outputs:size()-1 do
--         local out = outputs:get(i)
--         local mapper = out:getOutputMapper()
--         if mapper then
--             local list = ArrayList.new()
--             list:add("HorseMod.Horse_Head")
--             mapper:addOutputEntree("HorseMod.Horse_Skull", list)
--             mapper:OnPostWorldDictionaryInit(recipe:getName())
--         end
--     end
-- end