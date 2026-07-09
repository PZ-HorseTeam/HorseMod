---@namespace HorseMod

local Stamina = require("HorseMod/Stamina")
local AnimationVariable = require("HorseMod/definitions/AnimationVariable")
local MountedAnimationState = require("HorseMod/riding/MountedAnimationState")
local MountedDirection = require("HorseMod/riding/MountedDirection")

local rdm = newrandom()
local TEMP_VECTOR2 = Vector2.new()

local VEHICLE_SLIDE_TANGENT_SCALE = 1.08
local VEHICLE_SLIDE_OUTWARD_BIAS = 0.015
local VEHICLE_SLIDE_OUTWARD_BIAS_HEADON_DOT = 0.035
local VEHICLE_SLIDE_MIN_LEN_SQ = 0.00000005
local VEHICLE_COLLISION_RADIUS = 0.2
local VEHICLE_SLIDE_COLLISION_RADIUS = 0.14
local VEHICLE_SLIDE_GALLOP_MULT = 1.15

---Sets the angle that is considered wall collision
---So that you can slide against the wall at wider angles
---0.25 = sin^2(30deg)
local WALL_HIT_MIN_PROGRESS_FRACTION = 0.25

---@param state "walk"|"gallop"
---@return number
---@nodiscard
local function getSpeed(state)
    if state == "walk" then
        return SandboxVars.HorseMod.WalkSpeed ---@diagnostic disable-line
    end

    return SandboxVars.HorseMod.GallopSpeed ---@diagnostic disable-line
end

---@deprecated Use RidingMovement.getSpeed("walk") and RidingMovement.getSpeed("gallop") instead.
---@return number, number
function GetSpeeds()
    return getSpeed("walk"), getSpeed("gallop")
end

---@param horse IsoAnimal
---@return number
---@nodiscard
local function getGeneticSpeed(horse)
    return horse:getUsedGene("speed"):getCurrentValue()
end

---@param t number
---@return number
---@nodiscard
local function smoothstep(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    return t * t * (3 - 2 * t)
end

---@param a number
---@param b number
---@param t number
---@return number
---@nodiscard
local function lerp(a, b, t)
    return a + (b - a) * t
end

---@param x number
---@param y number
---@param z number
---@return IsoGridSquare?
---@nodiscard
local function getSq(x, y, z)
    return getCell():getGridSquare(math.floor(x), math.floor(y), z)
end

---So the horse doesn't trigger falling when going down stairs fast
local VERTICAL_FOLLOW_MAX_STEP = 0.95

---Sometimes the horse counts as airborne when reaching top of stairs for a few frames
---This gives it a bit of time to cover those frames
local RAMP_FALL_GRACE_SECONDS = 0.4

---Used to follow stair height, and to pick the collision Z level
---@param x number
---@param y number
---@param z number
---@return IsoGridSquare?
---@nodiscard
local function findFloorSquare(x, y, z)
    local cell = getCell()
    local xi = math.floor(x)
    local yi = math.floor(y)
    local top = math.floor(z)
    for level = top, 0, -1 do
        local sq = cell:getGridSquare(xi, yi, level)
        if sq and (sq:HasStairs() or sq:hasSlopedSurface() or sq:has(IsoFlagType.solidfloor)) then
            return sq
        end
    end

    return cell:getGridSquare(xi, yi, top)
end

---@param square IsoGridSquare
---@return boolean
---@nodiscard
local function squareIsRamp(square)
    return square:HasStairs() or square:hasSlopedSurface()
end

---@param treeMult number
---@return number
---@nodiscard
local function hedgeMultFromTree(treeMult)
    return 1.0 - (1.0 - treeMult) * 0.5
end

---@param square IsoGridSquare?
---@return "tree"|"hedge"|"bush"|"none"
---@nodiscard
local function getVegetationTypeAt(square)
    if not square then
        return "none"
    end

    local props = square:getProperties()

    local tree = square:getTree()
    local movementType = props:get("Movement")

    if tree and tree:getSize() > 2 then
        return "tree"
    elseif movementType == "HedgeLow" or movementType == "HedgeHigh" then
        return "hedge"
    elseif square:hasBush() then
        return "bush"
    end

    return "none"
end

---@param sq IsoGridSquare?
---@return boolean
---@nodiscard
local function squareCenterSolid(sq)
    if not sq then
        return true
    end

    if sq:isSolid() or sq:isSolidTrans() then
        return true
    end

    ---@type IsoObject[]
    local objects = sq:getLuaTileObjectList()
    for i = 1, #objects do
        local object = objects[i]
        local properties = object:getProperties()
        if properties
                and (properties:get("Solid") or properties:get("SolidTrans")) then
            return true
        end
    end

    return false
end

---@param rider IsoPlayer
---@param vehicles BaseVehicle[]
---@param worldX number
---@param worldY number
---@param worldZ number
---@param collisionRadius number
---@return boolean
---@return number
---@return number
---@nodiscard
local function riderCollidesWithVehicleAt(rider, vehicles, worldX, worldY, worldZ, collisionRadius)
    local oldNextX = rider:getNextX()
    local oldNextY = rider:getNextY()

    rider:setNextX(worldX)
    rider:setNextY(worldY)

    local collided = false
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if vehicle and math.floor(vehicle:getZ()) == worldZ then
            local dx = vehicle:getX() - worldX
            local dy = vehicle:getY() - worldY
            if (dx * dx + dy * dy) <= 36 then
                if vehicle:testCollisionWithCharacter(rider, collisionRadius, TEMP_VECTOR2) then
                    collided = true
                    break
                end
            end
        end
    end

    local hitX, hitY = TEMP_VECTOR2:getX(), TEMP_VECTOR2:getY()
    rider:setNextX(oldNextX)
    rider:setNextY(oldNextY)
    return collided, hitX, hitY
end

---@param worldX number
---@param worldY number
---@param moveX number
---@param moveY number
---@param collisionX number
---@param collisionY number
---@return number
---@return number
---@nodiscard
local function getVehicleSlideDelta(worldX, worldY, moveX, moveY, collisionX, collisionY)
    local normalX = collisionX - worldX
    local normalY = collisionY - worldY
    local normalLen = math.sqrt(normalX * normalX + normalY * normalY)
    if normalLen <= 0.0001 then
        return 0, 0
    end

    normalX = normalX / normalLen
    normalY = normalY / normalLen

    local tangentX = -normalY
    local tangentY = normalX
    local tangentDot = moveX * tangentX + moveY * tangentY

    local outwardBias = 0
    if math.abs(tangentDot) <= VEHICLE_SLIDE_OUTWARD_BIAS_HEADON_DOT then
        outwardBias = VEHICLE_SLIDE_OUTWARD_BIAS
    end

    local slideX = tangentX * tangentDot * VEHICLE_SLIDE_TANGENT_SCALE + normalX * outwardBias
    local slideY = tangentY * tangentDot * VEHICLE_SLIDE_TANGENT_SCALE + normalY * outwardBias

    if (slideX * slideX + slideY * slideY) <= VEHICLE_SLIDE_MIN_LEN_SQ then
        return 0, 0
    end

    return slideX, slideY
end

---@param a IsoGridSquare
---@param b IsoGridSquare
---@return IsoObject?
---@nodiscard
local function edgeHoppableBetween(a, b)
    local ax, ay = a:getX(), a:getY()
    local bx, by = b:getX(), b:getY()

    if by == ay then
        if bx == ax + 1 then
            return b:getHoppable(false)
        elseif bx == ax - 1 then
            return a:getHoppable(false)
        end
    elseif bx == ax then
        if by == ay + 1 then
            return b:getHoppable(true)
        elseif by == ay - 1 then
            return a:getHoppable(true)
        end
    end

    return nil
end

---@param fromSq IsoGridSquare
---@param toSq IsoGridSquare
---@param horse IsoAnimal
---@param isJumping boolean
---@return boolean
---@nodiscard
local function blockedBetween(fromSq, toSq, horse, isJumping)
    if fromSq == toSq then
        return false
    end

    local hop = edgeHoppableBetween(fromSq, toSq)
    if hop and hop:isHoppable() then
        if horse and isJumping then
            return false
        end

        return true
    end

    if fromSq:isWallTo(toSq) or toSq:isWallTo(fromSq)
            or fromSq:isWindowTo(toSq) or toSq:isWindowTo(fromSq) then
        return true
    end

    local door = fromSq:getDoorTo(toSq) ---@as IsoThumpable|IsoDoor|nil
    if door and not door:IsOpen() then
        return true
    end

    door = toSq:getDoorTo(fromSq) ---@as IsoThumpable|IsoDoor|nil
    if door and not door:IsOpen() then
        return true
    end

    return false
end

---@param fromX number
---@param fromY number
---@param toX number
---@param toY number
---@param z number
---@param horse IsoAnimal
---@param isJumping boolean
---@return boolean
---@nodiscard
local function canCross(fromX, fromY, toX, toY, z, horse, isJumping)
    local from = getSquare(fromX, fromY, z)
    local to = getSquare(toX, toY, z)

    if not from or not to then
        return false
    end

    return not blockedBetween(from, to, horse, isJumping) and not squareCenterSolid(to)
end

local EDGE_PAD = 0.01

---@param v number
---@return -1|0|1
---@nodiscard
local function signf(v)
    if v < 0 then
        return -1
    elseif v > 0 then
        return 1
    end

    return 0
end

---@param horse IsoAnimal
---@param z number
---@param x0 number
---@param y0 number
---@param dx number
---@param dy number
---@param isJumping boolean
---@return number
---@return number
---@nodiscard
local function collideStepAt(horse, z, x0, y0, dx, dy, isJumping)
    if dx == 0 and dy == 0 then return 0, 0 end

    local ox, oy = dx, dy
    local stepLen = math.sqrt(ox * ox + oy * oy)

    local fx, fy = math.floor(x0), math.floor(y0)
    local rx, ry = dx, dy

    if rx > 0 then
        if not canCross(fx, fy, fx + 1, fy, z, horse, isJumping) then
            local boundary = fx + 1 - EDGE_PAD
            if x0 + rx > boundary then rx = math.max(0, boundary - x0) end
        end
    elseif rx < 0 then
        if not canCross(fx - 1, fy, fx, fy, z, horse, isJumping) then
            local boundary = fx + EDGE_PAD
            if x0 + rx < boundary then rx = math.min(0, boundary - x0) end
        end
    end

    if ry > 0 then
        if not canCross(fx, fy, fx, fy + 1, z, horse, isJumping) then
            local boundary = fy + 1 - EDGE_PAD
            if y0 + ry > boundary then ry = math.max(0, boundary - y0) end
        end
    elseif ry < 0 then
        if not canCross(fx, fy - 1, fx, fy, z, horse, isJumping) then
            local boundary = fy + EDGE_PAD
            if y0 + ry < boundary then ry = math.min(0, boundary - y0) end
        end
    end

    if rx == 0 and ry == 0 then return 0, 0 end

    ---@param nx number
    ---@param ny number
    ---@return boolean
    ---@nodiscard
    local function centerBlocked(nx, ny)
        return squareCenterSolid(getSq(nx, ny, z))
    end

    local x1, y1 = x0 + rx, y0 + ry
    if centerBlocked(x1, y1) then
        local tryXFirst = math.abs(rx) >= math.abs(ry)

        ---@return number
        ---@return number
        ---@nodiscard
        local function tryProjectX()
            local px = signf(ox) * stepLen
            if px > 0 then
                if not canCross(fx, fy, fx + 1, fy, z, horse, isJumping) then
                    local b = fx + 1 - EDGE_PAD
                    if x0 + px > b then px = math.max(0, b - x0) end
                end
            elseif px < 0 then
                if not canCross(fx - 1, fy, fx, fy, z, horse, isJumping) then
                    local b = fx + EDGE_PAD
                    if x0 + px < b then px = math.min(0, b - x0) end
                end
            end
            if px ~= 0 and not centerBlocked(x0 + px, y0) then return px, 0 end
            return 0, 0
        end

        ---@return number
        ---@return number
        ---@nodiscard
        local function tryProjectY()
            local py = signf(oy) * stepLen
            if py > 0 then
                if not canCross(fx, fy, fx, fy + 1, z, horse, isJumping) then
                    local b = fy + 1 - EDGE_PAD
                    if y0 + py > b then py = math.max(0, b - y0) end
                end
            elseif py < 0 then
                if not canCross(fx, fy - 1, fx, fy, z, horse, isJumping) then
                    local b = fy + EDGE_PAD
                    if y0 + py < b then py = math.min(0, b - y0) end
                end
            end
            if py ~= 0 and not centerBlocked(x0, y0 + py) then return 0, py end
            return 0, 0
        end

        if tryXFirst then
            rx, ry = tryProjectX()
            if rx == 0 and ry == 0 then
                rx, ry = tryProjectY()
            end
        else
            rx, ry = tryProjectY()
            if rx == 0 and ry == 0 then
                rx, ry = tryProjectX()
            end
        end
        if rx == 0 and ry == 0 then return 0, 0 end
        x1, y1 = x0 + rx, y0 + ry
    end

    local tx, ty = math.floor(x1), math.floor(y1)
    local midSqX = (tx ~= fx) and getSquare(tx, fy, z)
    local midSqY = (ty ~= fy) and getSquare(fx, ty, z)
    local killedX, killedY = false, false
    if midSqX and squareCenterSolid(midSqX) then
        rx = 0
        killedX = true
    end
    if midSqY and squareCenterSolid(midSqY) then
        ry = 0
        killedY = true
    end

    if killedX and not killedY and ry ~= 0 then
        local py = signf(oy) * stepLen
        if py > 0 then
            if not canCross(fx, fy, fx, fy + 1, z, horse, isJumping) then
                local b = fy + 1 - EDGE_PAD
                if y0 + py > b then py = math.max(0, b - y0) end
            end
        elseif py < 0 then
            if not canCross(fx, fy - 1, fx, fy, z, horse, isJumping) then
                local b = fy + EDGE_PAD
                if y0 + py < b then py = math.min(0, b - y0) end
            end
        end
        if py ~= 0 and not centerBlocked(x0, y0 + py) then return 0, py end
        return 0, 0
    elseif killedY and not killedX and rx ~= 0 then
        local px = signf(ox) * stepLen
        if px > 0 then
            if not canCross(fx, fy, fx + 1, fy, z, horse, isJumping) then
                local b = fx + 1 - EDGE_PAD
                if x0 + px > b then px = math.max(0, b - x0) end
            end
        elseif px < 0 then
            if not canCross(fx - 1, fy, fx, fy, z, horse, isJumping) then
                local b = fx + EDGE_PAD
                if x0 + px < b then px = math.min(0, b - x0) end
            end
        end
        if px ~= 0 and not centerBlocked(x0 + px, y0) then return px, 0 end
        return 0, 0
    end

    if rx == 0 and ry == 0 then return 0, 0 end

    if (tx ~= fx) and (ty ~= fy) and (rx ~= 0) and (ry ~= 0) then
        local xFirstOk = (not midSqX or not squareCenterSolid(midSqX))
            and canCross(fx, fy, tx, fy, z, horse, isJumping)
            and canCross(tx, fy, tx, ty, z, horse, isJumping)
        local yFirstOk = (not midSqY or not squareCenterSolid(midSqY))
            and canCross(fx, fy, fx, ty, z, horse, isJumping)
            and canCross(fx, ty, tx, ty, z, horse, isJumping)
        if not xFirstOk and not yFirstOk then
            local px, py = signf(ox) * stepLen, signf(oy) * stepLen
            local rx1 = px
            if rx1 > 0 then
                if not canCross(fx, fy, fx + 1, fy, z, horse, isJumping) then
                    local b = fx + 1 - EDGE_PAD
                    if x0 + rx1 > b then rx1 = math.max(0, b - x0) end
                end
            elseif rx1 < 0 then
                if not canCross(fx - 1, fy, fx, fy, z, horse, isJumping) then
                    local b = fx + EDGE_PAD
                    if x0 + rx1 < b then rx1 = math.min(0, b - x0) end
                end
            end
            local okX = (rx1 ~= 0) and not squareCenterSolid(getSquare(x0 + rx1, y0, z))

            local ry2 = py
            if ry2 > 0 then
                if not canCross(fx, fy, fx, fy + 1, z, horse, isJumping) then
                    local b = fy + 1 - EDGE_PAD
                    if y0 + ry2 > b then ry2 = math.max(0, b - y0) end
                end
            elseif ry2 < 0 then
                if not canCross(fx, fy - 1, fx, fy, z, horse, isJumping) then
                    local b = fy + EDGE_PAD
                    if y0 + ry2 < b then ry2 = math.min(0, b - y0) end
                end
            end
            local okY = (ry2 ~= 0) and not squareCenterSolid(getSquare(x0, y0 + ry2, z))

            if okX and not okY then return rx1, 0 end
            if okY and not okX then return 0, ry2 end
            if okX and okY then
                if math.abs(ox) >= math.abs(oy) then
                    return rx1, 0
                end

                return 0, ry2
            end
            return 0, 0
        end
    end

    return rx, ry
end

---@param current number
---@param target number
---@param amount number
---@return number
---@nodiscard
local function approach(current, target, amount)
    local delta = target - current
    if delta > 0 then
        local step = math.min(delta, amount)
        return current + step
    end

    local step = math.max(delta, -amount)
    return current + step
end

local TWO_PI = math.pi * 2

---@param angle number
---@return number
---@nodiscard
local function wrapAnglePi(angle)
    angle = (angle + math.pi) % TWO_PI
    if angle < 0 then
        angle = angle + TWO_PI
    end

    return angle - math.pi
end

---@param direction IsoDirections
---@return number
---@nodiscard
local function directionToAngle(direction)
    return Vector2.getDirection(direction:dx(), direction:dy())
end

---@param direction IsoDirections
---@return number
---@nodiscard
local function directionToDegrees(direction)
    return directionToAngle(direction) * (180 / math.pi)
end

local TREES_GENE_MULT_WALK = 0.40
local TREES_GENE_MULT_RUN = 0.25
local TREES_LINGER_SECONDS = 1.0
local TURN_STEPS_PER_SEC = 60
local JUMP_SECONDS = 0.85
local JUMP_COOLDOWN_SECONDS = 1.4
local IDLE_TO_RUN_SECONDS = 0.6

local BASE_CHANCE = 0.1
local NIMBLE_LOW = 1
local NIMBLE_HIGH = 0
local TRAITS = {
    [CharacterTrait.EAGLE_EYED] = 0.5,
    [CharacterTrait.GYMNAST] = 0.5,
    [CharacterTrait.MOTION_SENSITIVE] = 2,
    [CharacterTrait.CLUMSY] = 2,
}

local SLOWDOWN_MAX = 2.5
local SLOWDOWN_ZOMBIE_KNOCKDOWN_INCREASE = 0.75
local SLOWDOWN_ZOMBIE_NEARBY_INCREASE = 4
local SLOWDOWN_ZOMBIE_GROUND_INCREASE = 2
local SLOWDOWN_MIN_SECONDS = 1
local SLOWDOWN_MAX_SECONDS = 2
local SLOWDOWN_MAX_SCALAR = 0.2
local SLOWDOWN_MIN_SPEED = 2
local KNOCKDOWN_MIN_SPEED = 6.5

local SPEED_WALK = 1.6
local SPEED_TROT = 4
local SPEED_GALLOP = 8.5
local ACCELERATION_RATE = 12
local DECELERATION_RATE = 9
local SPEED_FACTOR_TURN = 0.8
local TURN_ANIM_HOLD_SECONDS = 0.20

---@class RidingMovementInput
---@field movement {x: number, y: number}
---@field run boolean
---@field trot boolean
---@field jump boolean
---@field hasReins boolean?

---@class RidingMovementEffects
---@field authoritative boolean
---@field onGallopBlocked fun(rider: IsoPlayer, horse: IsoAnimal)?
---@field onTreeFall fun(rider: IsoPlayer, horse: IsoAnimal)?
---@field onFallDetected fun(rider: IsoPlayer, horse: IsoAnimal)?

---@class RidingMovement
---@field pair MountPair
---@field effects RidingMovementEffects
---@field turnAcceleration number
---@field lastTurnWasRight boolean
---@field vegetationLingerTime number
---@field vegetationLingerStartMult number
---@field speed number
---@field timeInTrees number
---@field lastCheck number
---@field slowdownCounter number
---@field doTurn boolean
---@field forcedInput RidingMovementInput?
---@field jumpTime number
---@field jumpCooldown number
---@field lastAuthoritativeSeq integer
---@field direction IsoDirections
---@field turnAnimSign integer
---@field turnAnimTime number
---@field wasGalloping boolean
---@field idleToRunTimer number
---@field lastFloorSquare IsoGridSquare?
---@field rampGrace number
local RidingMovement = {}
RidingMovement.__index = RidingMovement

RidingMovement.getSpeed = getSpeed

---@param rider IsoPlayer
---@param horse IsoAnimal
---@param distance Vector2
---@param isGalloping boolean
---@param isJumping boolean
---@param effects RidingMovementEffects
local function moveWithCollision(rider, horse, distance, isGalloping, isJumping, effects)
    local floorSquare = findFloorSquare(horse:getX(), horse:getY(), horse:getZ())

    -- Collide at the resolved floor level so the rider can't pass through walls
    -- when going up/down stairs
    local baseZ = floorSquare and floorSquare:getZ() or math.floor(horse:getZ())
    local onStairs = floorSquare ~= nil and floorSquare:HasStairs()

    local onRamp = floorSquare ~= nil and squareIsRamp(floorSquare)
    if not onRamp then
        local below = getSq(horse:getX(), horse:getY(), math.floor(horse:getZ()) - 1)
        onRamp = below ~= nil and squareIsRamp(below)
    end

    local x = horse:getX()
    local y = horse:getY()
    local candidates = {}

    local maxProbeDistance = math.sqrt(36) + distance:getLength() + 1
    local maxProbeDistanceSq = maxProbeDistance * maxProbeDistance
    local allVehicles = getCell():getVehicles()
    if allVehicles then
        local it = allVehicles:iterator()
        while it:hasNext() do
            local vehicle = it:next()
            if vehicle and math.floor(vehicle:getZ()) == baseZ then
                local dx = vehicle:getX() - x
                local dy = vehicle:getY() - y
                if (dx * dx + dy * dy) <= maxProbeDistanceSq then
                    candidates[#candidates + 1] = vehicle
                end
            end
        end
    end

    local function stepAt(sx, sy, reqX, reqY)
        local rx, ry = collideStepAt(horse, baseZ, sx, sy, reqX, reqY, isJumping)
        local sz = baseZ
        if onStairs then
            local ux, uy = collideStepAt(horse, baseZ + 1, sx, sy, reqX, reqY, isJumping)
            if (ux * ux + uy * uy) > (rx * rx + ry * ry) then
                local dest = getSquare(sx + ux, sy + uy, baseZ + 1)
                if dest and (dest:has(IsoFlagType.solidfloor) or dest:HasStairs()) then
                    rx, ry, sz = ux, uy, baseZ + 1
                end
            end
        end
        return rx, ry, sz
    end

    local maxStepDist = 0.065
    local remaining = distance:getLength()
    while remaining > 0 do
        local magnitude = math.min(remaining, maxStepDist)
        distance:setLength(magnitude)

        local reqX, reqY = distance:getX(), distance:getY()
        local rx, ry, stepZ = stepAt(x, y, reqX, reqY)
        if rx == 0 and ry == 0 then
            if isGalloping and effects.onGallopBlocked and not onRamp then
                effects.onGallopBlocked(rider, horse)
            end
            break
        end

        if isGalloping and effects.onGallopBlocked and not onRamp and magnitude > 0 then
            local progressAlongDir = (rx * reqX + ry * reqY) / magnitude
            if progressAlongDir < magnitude * WALL_HIT_MIN_PROGRESS_FRACTION then
                effects.onGallopBlocked(rider, horse)
                break
            end
        end

        local nx = x + rx
        local ny = y + ry
        local hitVehicle, hitX, hitY = riderCollidesWithVehicleAt(rider, candidates, nx, ny, baseZ, VEHICLE_COLLISION_RADIUS)
        if hitVehicle then
            local sx, sy = getVehicleSlideDelta(nx, ny, rx, ry, hitX, hitY)
            if sx == 0 and sy == 0 then
                break
            end
            if isGalloping then
                sx = sx * VEHICLE_SLIDE_GALLOP_MULT
                sy = sy * VEHICLE_SLIDE_GALLOP_MULT
            end

            local snx = x + sx
            local sny = y + sy
            local slideBlockedVehicle = riderCollidesWithVehicleAt(rider, candidates, snx, sny, baseZ, VEHICLE_SLIDE_COLLISION_RADIUS)
            if slideBlockedVehicle or squareCenterSolid(getSquare(snx, sny, baseZ)) then
                snx = x + sx * 0.6
                sny = y + sy * 0.6
                slideBlockedVehicle = riderCollidesWithVehicleAt(rider, candidates, snx, sny, baseZ, VEHICLE_SLIDE_COLLISION_RADIUS)
                if slideBlockedVehicle or squareCenterSolid(getSquare(snx, sny, baseZ)) then
                    snx = x - sx * 0.6
                    sny = y - sy * 0.6
                    slideBlockedVehicle = riderCollidesWithVehicleAt(rider, candidates, snx, sny, baseZ, VEHICLE_SLIDE_COLLISION_RADIUS)
                    if slideBlockedVehicle or squareCenterSolid(getSquare(snx, sny, baseZ)) then
                        break
                    end
                end
            end

            nx = snx
            ny = sny
        end

        if squareCenterSolid(getSquare(nx, ny, stepZ)) then
            break
        end

        x = nx
        y = ny
        remaining = remaining - magnitude
    end

    horse:setX(x)
    horse:setY(y)
end

---@param args RidingStateArguments
---@return boolean
---@nodiscard
local function hasValidStateTransform(args)
    return type(args.x) == "number"
        and type(args.y) == "number"
        and type(args.z) == "number"
        and type(args.dir) == "number"
        and type(args.speed) == "number"
end

---@param args RidingStateArguments
---@return integer
---@nodiscard
local function getStateTurn(args)
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

---@param pair MountPair
---@param isMoving boolean
---@param isGalloping boolean
local function setMountedMovementVariables(pair, isMoving, isGalloping)
    MountedAnimationState.setMovementVariables(pair.rider, pair.mount, isMoving, isGalloping)
end

---@param rider IsoPlayer
---@param x number
---@param y number
---@param z number
local function setRiderMountedPosition(rider, x, y, z)
    rider:setForceX(x)
    rider:setForceY(y)
    rider:setZ(z)
end

---@param pair MountPair
---@param args RidingStateArguments
function RidingMovement.applyState(pair, args)
    if not hasValidStateTransform(args) then
        return
    end

    local rider = pair.rider
    local mount = pair.mount
    local dir = IsoDirections.fromIndex(math.floor(args.dir))

    mount:setX(args.x)
    mount:setY(args.y)
    mount:setZ(args.z)
    mount:getPathFindBehavior2():reset()
    mount:setPath2(nil)
    mount:setMoving(args.speed > 0)
    mount:setVariable("bPathfind", false)
    setRiderMountedPosition(rider, args.x, args.y, args.z)

    -- Snap reconciliation: discard any cached body-angle so the body resyncs
    -- to the new pose rather than slowly turning toward it from where it
    -- was before the snap.
    MountedDirection.clear(mount)
    MountedDirection.setPair(pair, dir)
    MountedAnimationState.setSpeedVariables(rider, mount)
    MountedAnimationState.setReinsVariable(rider, args.hasReins == true)
    MountedAnimationState.setTurnVariables(rider, mount, getStateTurn(args))
    pair:setAnimationVariable(AnimationVariable.GALLOP, args.gallop == true)
    pair:setAnimationVariable(AnimationVariable.TROT, args.trot == true)
    pair:setAnimationVariable(AnimationVariable.JUMP, args.jump == true)
    pair:setAnimationVariable(AnimationVariable.IDLE_TO_RUN, args.idleToRun == true)

    setMountedMovementVariables(pair, args.speed > 0, args.gallop == true)
end

---@param args RidingStateArguments
---@param snapDistanceSq number
function RidingMovement:applyAuthoritativeState(args, snapDistanceSq)
    if not hasValidStateTransform(args) then
        return
    end

    if type(args.seq) == "number" then
        local seq = math.floor(args.seq)
        if seq < self.lastAuthoritativeSeq then
            return
        end
        self.lastAuthoritativeSeq = seq
    end

    local pair = self.pair
    local mount = pair.mount
    local dx = mount:getX() - args.x
    local dy = mount:getY() - args.y
    local dz = mount:getZ() - args.z
    if (dx * dx + dy * dy + dz * dz) > snapDistanceSq then
        self.speed = args.speed
        self.direction = IsoDirections.fromIndex(math.floor(args.dir))
        RidingMovement.applyState(self.pair, args)
        self.lastAppliedX = args.x
        self.lastAppliedY = args.y
        self.lastAppliedZ = args.z
        self.lastAppliedDir = math.floor(args.dir)
        return
    end

    if args.speed > self.speed then
        self.speed = args.speed
    end

    self.pair:setAnimationVariable(AnimationVariable.GALLOP, args.gallop == true)
    self.pair:setAnimationVariable(AnimationVariable.TROT, args.trot == true)
    self.pair:setAnimationVariable(AnimationVariable.JUMP, args.jump == true)
    MountedAnimationState.setReinsVariable(pair.rider, args.hasReins == true)
    MountedAnimationState.setTurnVariables(pair.rider, mount, getStateTurn(args))
    setMountedMovementVariables(pair, args.speed > 0, args.gallop == true)
end

---@param args RidingStateArguments
---@param recoveryDistanceSq number
function RidingMovement:applyRecoveryState(args, recoveryDistanceSq)
    if not hasValidStateTransform(args) then
        return
    end

    if type(args.seq) == "number" then
        local seq = math.floor(args.seq)
        if seq < self.lastAuthoritativeSeq then
            return
        end
        self.lastAuthoritativeSeq = seq
    end

    local mount = self.pair.mount
    local dx = mount:getX() - args.x
    local dy = mount:getY() - args.y
    local dz = mount:getZ() - args.z
    if (dx * dx + dy * dy + dz * dz) > recoveryDistanceSq then
        self.speed = args.speed
        self.direction = IsoDirections.fromIndex(math.floor(args.dir))
        RidingMovement.applyState(self.pair, args)
        self.lastAppliedX = args.x
        self.lastAppliedY = args.y
        self.lastAppliedZ = args.z
        self.lastAppliedDir = math.floor(args.dir)
    end
end

---@return number
---@nodiscard
function RidingMovement:calculateTreeFallChance()
    local rider = self.pair.rider
    local skill = rider:getPerkLevel(Perks.Nimble)
    local chance = BASE_CHANCE * self.timeInTrees * ((NIMBLE_HIGH - NIMBLE_LOW) / 10 * skill + NIMBLE_LOW)

    for trait, mult in pairs(TRAITS) do
        if rider:hasTrait(trait) then
            chance = chance * mult
        end
    end

    return chance
end

---@return boolean
function RidingMovement:rollForTreeFall()
    local chance = self:calculateTreeFallChance()
    local pass = rdm:random() < chance
    if pass then
        if self.effects.onTreeFall then
            self.effects.onTreeFall(self.pair.rider, self.pair.mount)
        end
        return true
    end

    return false
end

---@param deltaTime number
function RidingMovement:updateSlowdown(deltaTime)
    self.slowdownCounter = math.max(self.slowdownCounter - deltaTime, 0)

    local square = self.pair.mount:getSquare()
    if not square then
        return
    end

    local movingObjects = square:getLuaMovingObjectList() ---@as IsoMovingObject[]
    for i = 1, #movingObjects do
        local zombie = movingObjects[i]
        if instanceof(zombie, "IsoZombie") then
            ---@cast zombie IsoZombie
            if zombie:isKnockedDown() or zombie:isCrawling() then
                self.slowdownCounter = self.slowdownCounter + SLOWDOWN_ZOMBIE_GROUND_INCREASE * deltaTime
            else
                if self.speed >= KNOCKDOWN_MIN_SPEED then
                    self.slowdownCounter = self.slowdownCounter + SLOWDOWN_ZOMBIE_KNOCKDOWN_INCREASE
                    if self.effects.authoritative then
                        local facingSameDir = math.abs(zombie:getDirectionAngle() - directionToDegrees(self.direction)) <= 180
                        zombie:knockDown(facingSameDir)
                    end
                else
                    self.slowdownCounter = self.slowdownCounter + SLOWDOWN_ZOMBIE_NEARBY_INCREASE * deltaTime
                end
            end
        end
    end

    self.slowdownCounter = math.min(self.slowdownCounter, SLOWDOWN_MAX)
end

---@param input RidingMovementInput
---@param deltaTime number
function RidingMovement:turn(input, deltaTime)
    local currentDirection = self.direction

    local targetDirection = currentDirection
    if input.movement.x ~= 0 or input.movement.y ~= 0 then
        targetDirection = IsoDirections.fromAngle(input.movement.x, input.movement.y):RotLeft()
    end

    self.turnAcceleration = self.turnAcceleration + deltaTime * TURN_STEPS_PER_SEC
    local turnDistance = currentDirection:compareTo(targetDirection)
    local absoluteTurnDistance = math.abs(turnDistance)
    if absoluteTurnDistance > 4 then
        turnDistance = (-turnDistance + 4) % 8
    end

    local turns = math.min(math.floor(self.turnAcceleration), absoluteTurnDistance)
    local shouldTurnRight = self.lastTurnWasRight
    if turnDistance == 0 then
        turns = 0
        self.turnAcceleration = 0
    elseif absoluteTurnDistance ~= 4 then
        shouldTurnRight = turnDistance > 0
    else
        local rider = self.pair.rider
        local currentAngle = rider:getAnimAngleRadians()
        if not currentAngle then
            currentAngle = directionToAngle(currentDirection)
        end

        local targetAngle = directionToAngle(targetDirection)
        local delta = wrapAnglePi(targetAngle - currentAngle)
        if delta ~= 0 then
            shouldTurnRight = delta > 0
        end
    end

    if turns >= 1 then
        if shouldTurnRight then
            currentDirection = currentDirection:RotRight(turns)
        else
            currentDirection = currentDirection:RotLeft(turns)
        end
        self.turnAcceleration = self.turnAcceleration % 1
    end

    self.lastTurnWasRight = shouldTurnRight
    self.direction = currentDirection
    MountedDirection.setPair(self.pair, currentDirection, deltaTime, nil, targetDirection)

    local turnSign = 0
    if turnDistance ~= 0 then
        if shouldTurnRight then
            turnSign = 1
        else
            turnSign = -1
        end
    end

    if turnSign ~= 0 then
        self.turnAnimSign = turnSign
        self.turnAnimTime = TURN_ANIM_HOLD_SECONDS
    elseif self.turnAnimTime > 0 then
        self.turnAnimTime = math.max(0, self.turnAnimTime - deltaTime)
        if self.turnAnimTime == 0 then
            self.turnAnimSign = 0
        end
    else
        self.turnAnimSign = 0
    end

    MountedAnimationState.setTurnVariables(self.pair.rider, self.pair.mount, self.turnAnimSign)
end

---@param input RidingMovementInput
---@param deltaTime number
---@return number
---@nodiscard
function RidingMovement:getVegetationEffect(input, deltaTime)
    local vegetationType = getVegetationTypeAt(self.pair.rider:getSquare())
    local treeMultiplier = input.run and TREES_GENE_MULT_RUN or TREES_GENE_MULT_WALK

    if vegetationType ~= "none" then
        local vegetationEffect
        if vegetationType == "tree" then
            vegetationEffect = treeMultiplier
        elseif vegetationType == "hedge" then
            vegetationEffect = hedgeMultFromTree(treeMultiplier)
        else
            vegetationEffect = 1.0
        end

        self.vegetationLingerTime = math.max(self.vegetationLingerTime, TREES_LINGER_SECONDS)
        self.vegetationLingerStartMult = math.min(self.vegetationLingerStartMult, vegetationEffect)
        return vegetationEffect
    end

    if self.vegetationLingerTime <= 0 then
        return 1.0
    end

    local p = 1.0 - (self.vegetationLingerTime / TREES_LINGER_SECONDS)
    local eased = smoothstep(p)
    self.vegetationLingerTime = math.max(0, self.vegetationLingerTime - deltaTime)

    return lerp(self.vegetationLingerStartMult, 1.0, eased)
end

---@param input RidingMovementInput
---@return number
---@nodiscard
function RidingMovement:getTargetSpeed(input)
    if input.run then
        return SPEED_GALLOP * math.max(getSpeed("gallop") * Stamina.runSpeedFactor(self.pair.mount), 0.35)
    elseif self.pair.mount:getVariableBoolean(AnimationVariable.TROT) then
        return SPEED_TROT * getSpeed("walk")
    end

    return SPEED_WALK * getSpeed("walk")
end

---@param input RidingMovementInput
---@param deltaTime number
function RidingMovement:updateSpeed(input, deltaTime)
    self:updateSlowdown(deltaTime)

    local pair = self.pair
    local mount = pair.mount
    local rider = pair.rider

    local vegetationEffect = self:getVegetationEffect(input, deltaTime)
    local geneSpeed = getGeneticSpeed(mount) * vegetationEffect

    MountedAnimationState.setSpeedVariables(rider, mount, geneSpeed)

    local target = 0.0
    local moving = (input.movement.x ~= 0 or input.movement.y ~= 0)
    if moving then
        target = self:getTargetSpeed(input)
    elseif mount:isTurning() then
        target = self:getTargetSpeed(input) * SPEED_FACTOR_TURN
    end

    target = target * vegetationEffect

    local rate = (target > self.speed) and ACCELERATION_RATE or DECELERATION_RATE
    self.speed = approach(self.speed, target, rate * deltaTime)

    if self.speed > SLOWDOWN_MIN_SPEED then
        if self.slowdownCounter >= SLOWDOWN_MIN_SECONDS then
            local slowdownAmount = math.min(
                math.max(self.slowdownCounter - SLOWDOWN_MIN_SECONDS, 0),
                SLOWDOWN_MAX_SECONDS - SLOWDOWN_MIN_SECONDS
            )
            local slowdownScalar = PZMath.lerp(
                1,
                SLOWDOWN_MAX_SCALAR,
                slowdownAmount / (SLOWDOWN_MAX_SECONDS - SLOWDOWN_MIN_SECONDS)
            )
            self.speed = math.min(self.speed, target * slowdownScalar)
        end

        self.speed = math.max(self.speed, SLOWDOWN_MIN_SPEED)
    end

    if self.speed < 0.01 then
        self.speed = 0
    end
end

---@param isGalloping boolean
---@param deltaTime number
function RidingMovement:updateTreeFall(isGalloping, deltaTime)
    local rider = self.pair.rider
    local mount = self.pair.mount
    local timeInTrees = self.timeInTrees

    if isGalloping then
        if rider:isInTreesNoBush() or mount:isInTreesNoBush() then
            self.timeInTrees = timeInTrees + deltaTime
            if self.lastCheck > 0.5 then
                self:rollForTreeFall()
                self.lastCheck = 0.0
            else
                self.lastCheck = self.lastCheck + deltaTime
            end
        end
    elseif self.timeInTrees > 0 then
        timeInTrees = math.max(0, timeInTrees - deltaTime * 4)
        timeInTrees = math.min(timeInTrees, 10)
        self.timeInTrees = timeInTrees
    end
end

---@return "idle"|"walking"|"trot"|"gallop"
---@nodiscard
function RidingMovement:getMovementState()
    if self.speed <= 0.01 then
        return "idle"
    elseif self.pair:getAnimationVariableBoolean(AnimationVariable.GALLOP) then
        return "gallop"
    elseif self.pair:getAnimationVariableBoolean(AnimationVariable.TROT) then
        return "trot"
    end

    return "walking"
end

function RidingMovement:toggleTrot()
    local current = self.pair:getAnimationVariableBoolean(AnimationVariable.TROT)
    self.pair:setAnimationVariable(AnimationVariable.TROT, not current)
end

---@return number
---@nodiscard
function RidingMovement:getCurrentSpeed()
    return self.speed
end

---@return IsoDirections
---@nodiscard
function RidingMovement:getDirection()
    return self.direction
end

---@param speed number
function RidingMovement:setCurrentSpeed(speed)
    self.speed = speed
end

---@return boolean
---@nodiscard
function RidingMovement:canJump()
    return self.pair.mount:getVariableBoolean(AnimationVariable.GALLOP)
        and self:getCurrentSpeed() > 6
        and not self.pair:getAnimationVariableBoolean(AnimationVariable.JUMP)
        and self.jumpCooldown <= 0
end

function RidingMovement:startJump()
    local character = self.pair.rider
    self.pair:setAnimationVariable(AnimationVariable.JUMP, true)
    character:setIgnoreMovement(true)
    character:setIgnoreInputsForDirection(true)
    character:setIgnoreAimingInput(true)
    character:setIsAiming(false)

    self.doTurn = false
    self.jumpTime = JUMP_SECONDS
    self.jumpCooldown = JUMP_COOLDOWN_SECONDS
end

---SP path drives jumps through the HorseJump timed action instead of startJump,
---so expose just the cooldown so the action can share the same canJump lockout
function RidingMovement:beginJumpCooldown()
    self.jumpCooldown = JUMP_COOLDOWN_SECONDS
end

function RidingMovement:resetJump()
    local character = self.pair.rider
    if character:getVariableBoolean(AnimationVariable.RIDING_HORSE) then
        character:setIgnoreMovement(true)
        character:setIgnoreInputsForDirection(true)
        character:setIgnoreAimingInput(true)
    else
        character:setIgnoreMovement(false)
        character:setIgnoreInputsForDirection(false)
        character:setIgnoreAimingInput(false)
    end

    self.pair:setAnimationVariable(AnimationVariable.JUMP, false)
    self.doTurn = true
    self.forcedInput = nil
    self.jumpTime = 0
end

---@param input RidingMovementInput
---@param deltaTime number
function RidingMovement:updateJump(input, deltaTime)
    self.jumpCooldown = math.max(0, self.jumpCooldown - deltaTime)

    if input.jump and self:canJump() then
        self.forcedInput = {
            movement = {
                x = input.movement.x,
                y = input.movement.y,
            },
            run = true,
            trot = input.trot,
            jump = false,
        }
        self:startJump()
    end

    if self.jumpTime <= 0 then
        return
    end

    self.jumpTime = self.jumpTime - deltaTime
    if self.jumpTime <= 0 then
        self:resetJump()
    end
end

---@return boolean
---@nodiscard
function RidingMovement:isJumping()
    return self.jumpTime > 0 or self.pair:getAnimationVariableBoolean(AnimationVariable.JUMP)
end

---@param sq IsoGridSquare
---@param x number
---@param y number
---@return number
---@nodiscard
local function floorHeight(sq, x, y)
    if squareIsRamp(sq) then
        return sq:getApparentZ(x - sq:getX(), y - sq:getY())
    end

    return sq:getZ()
end

---Make the horse track the floor height of stairs and landings.
---@param mount IsoAnimal
---@param deltaTime number
function RidingMovement:followVertical(mount, deltaTime)
    local x = mount:getX()
    local y = mount:getY()
    local mz = mount:getZ()

    local best = findFloorSquare(x, y, mz)
    local bestZ = best and floorHeight(best, x, y) or nil

    -- Only look a level up when the mount is in the upper part of its Z level, so a
    -- mount on Z-0 is never teleported up to a floor above
    if (mz - math.floor(mz)) >= 0.5 then
        local above = getSq(x, y, math.floor(mz) + 1)
        if above and (above:has(IsoFlagType.solidfloor) or above:HasStairs() or above:hasSlopedSurface()) then
            local zAbove = floorHeight(above, x, y)
            if (not bestZ) or math.abs(zAbove - mz) < math.abs(bestZ - mz) then
                best, bestZ = above, zAbove
            end
        end
    end

    if not best then
        self.lastFloorSquare = nil
        self.rampGrace = math.max(0, self.rampGrace - deltaTime)
        return
    end

    if math.abs(bestZ - mz) < VERTICAL_FOLLOW_MAX_STEP then
        mount:setZ(bestZ)
        mount:setLastZ(bestZ)
    end

    -- Refresh the square that the mount is on
    mount:setCurrent(best)
    mount:setMovingSquareNow()

    if squareIsRamp(best) then
        self.rampGrace = RAMP_FALL_GRACE_SECONDS
    else
        self.rampGrace = math.max(0, self.rampGrace - deltaTime)
    end

    self.lastFloorSquare = best
end


---@param mount IsoAnimal
---@return boolean
---@nodiscard
function RidingMovement:onStairsOrSlope(mount)
    if self.rampGrace > 0 then
        return true
    end

    local square = self.lastFloorSquare or findFloorSquare(mount:getX(), mount:getY(), mount:getZ())
    if square ~= nil and squareIsRamp(square) then
        return true
    end

    local below = getCell():getGridSquare(math.floor(mount:getX()), math.floor(mount:getY()), math.floor(mount:getZ()) - 1)
    return below ~= nil and squareIsRamp(below)
end

---`isbFalling` triggers on the mount whenever there's a floor below it seems
---so can't always be trusted to do what it says
---@param mount IsoAnimal
---@return boolean
---@nodiscard
function RidingMovement:isOnFloor(mount)
    local x, y = mount:getX(), mount:getY()
    local mz = mount:getZ()

    local below = findFloorSquare(x, y, mz)
    if below then
        local bz = squareIsRamp(below)
            and below:getApparentZ(x - below:getX(), y - below:getY())
            or below:getZ()
        if math.abs(bz - mz) <= 0.35 then
            return true
        end
    end

    local above = getSq(x, y, math.floor(mz) + 1)
    if above and (above:has(IsoFlagType.solidfloor) or above:HasStairs() or above:hasSlopedSurface()) then
        if math.abs(above:getZ() - mz) <= 0.35 then
            return true
        end
    end

    return false
end

---@param input RidingMovementInput
---@param deltaTime number
function RidingMovement:update(input, deltaTime)
    assert(self.pair.rider:getVariableString(AnimationVariable.RIDING_HORSE) == "true")

    local rider = self.pair.rider
    local mount = self.pair.mount

    if self.effects.authoritative == false and self.lastAppliedX then
        mount:setX(self.lastAppliedX)
        mount:setY(self.lastAppliedY)
        mount:setZ(self.lastAppliedZ)
        mount:setLastX(self.lastAppliedX)
        mount:setLastY(self.lastAppliedY)
        mount:setLastZ(self.lastAppliedZ)
        if self.lastAppliedDir then
            self.direction = IsoDirections.fromIndex(self.lastAppliedDir)
            MountedDirection.setPair(self.pair, self.direction, deltaTime)
        end
    end

    self.pair:setAnimationVariable(AnimationVariable.TROT, input.trot == true)
    self:updateJump(input, deltaTime)

    local forcedInput = self.forcedInput
    if forcedInput then
        input = forcedInput
    end

    rider:setSneaking(false)
    rider:setIgnoreAutoVault(true)

    mount:getPathFindBehavior2():reset()
    mount:setVariable("bPathfind", false)

    local moving = (input.movement.x ~= 0 or input.movement.y ~= 0)
    local isGalloping = self:getMovementState() == "gallop"

    -- to suppress IdleToGallop replaying when reversing direction
    local rawRunHeld = input.run == true

    if not Stamina.shouldRun(mount, input, moving) then
        input.run = false
    else
        input.run = true
    end

    local isJumping = self:isJumping()
    if not isJumping then
        self.doTurn = true
    end

    if self.doTurn then
        self:turn(input, deltaTime)
    end

    self:updateSpeed(input, deltaTime)

    local needsEngineMoving = isServer()
    local gallopActive
    if self.speed > 0 and not rider:getVariableBoolean(AnimationVariable.DISMOUNT_STARTED) then
        local moveAngle = MountedDirection.getMovementAngle(mount, self.direction)
        TEMP_VECTOR2:setLengthAndDirection(moveAngle, self.speed * deltaTime)
        moveWithCollision(rider, mount, TEMP_VECTOR2, isGalloping, isJumping, self.effects)

        gallopActive = input.run == true
        self.pair:setAnimationVariable(AnimationVariable.GALLOP, gallopActive)
        -- mount:setMoving(true) only needed on the server
        -- so animal sync sends the moving state to other clients
        setMountedMovementVariables(self.pair, true, gallopActive)
        if needsEngineMoving then
            mount:setMoving(true)
        end
    else
        gallopActive = false
        self.pair:setAnimationVariable(AnimationVariable.GALLOP, false)
        setMountedMovementVariables(self.pair, false, false)
        if needsEngineMoving then
            mount:setMoving(false)
        end
    end

    if gallopActive and not self.wasGalloping then
        self.idleToRunTimer = IDLE_TO_RUN_SECONDS
    elseif not gallopActive then
        self.idleToRunTimer = 0
    elseif self.idleToRunTimer > 0 then
        self.idleToRunTimer = math.max(0, self.idleToRunTimer - deltaTime)
    end
    self.pair:setAnimationVariable(AnimationVariable.IDLE_TO_RUN, self.idleToRunTimer > 0)

    if not rawRunHeld then
        self.wasGalloping = false
    elseif gallopActive then
        self.wasGalloping = true
    end

    -- Follow stair height before pinning the rider so they both
    -- go up/down stairs together
    self:followVertical(mount, deltaTime)

    setRiderMountedPosition(rider, mount:getX(), mount:getY(), mount:getZ())

    self:updateTreeFall(isGalloping, deltaTime)

    if (rider:isbFalling() or mount:isbFalling())
            and not self:onStairsOrSlope(mount)
            and not self:isOnFloor(mount) then
        if self.effects.onFallDetected then
            self.effects.onFallDetected(rider, mount)
        end
    end

    if self.effects.authoritative == false then
        self.lastAppliedX = mount:getX()
        self.lastAppliedY = mount:getY()
        self.lastAppliedZ = mount:getZ()
        self.lastAppliedDir = self.direction:ordinal()
    end
end

---@param pair MountPair
---@param effects RidingMovementEffects
---@return RidingMovement
---@nodiscard
function RidingMovement.new(pair, effects)
    return setmetatable(
        {
            pair = pair,
            effects = effects,
            turnAcceleration = 0,
            lastTurnWasRight = false,
            vegetationLingerTime = 0.0,
            vegetationLingerStartMult = 1.0,
            timeInTrees = 0.0,
            lastCheck = 0.0,
            slowdownCounter = 0.0,
            speed = 0.0,
            doTurn = true,
            forcedInput = nil,
            jumpTime = 0,
            jumpCooldown = 0,
            lastAuthoritativeSeq = -1,
            direction = pair.rider:getDir(),
            turnAnimSign = 0,
            turnAnimTime = 0.0,
            lastAppliedX = nil--[[@as number?]],
            lastAppliedY = nil--[[@as number?]],
            lastAppliedZ = nil--[[@as number?]],
            lastAppliedDir = nil--[[@as integer?]],
            wasGalloping = false,
            idleToRunTimer = 0.0,
            lastFloorSquare = nil--[[@as IsoGridSquare?]],
            rampGrace = 0.0,
        },
        RidingMovement
    )
end

return RidingMovement
