---REQUIREMENTS
local Stamina = require("HorseMod/Stamina")
local AnimationVariable = require('HorseMod/definitions/AnimationVariable')
local Mounting = require("HorseMod/Mounting")
local HorseJump = require("HorseMod/TimedActions/HorseJump")
local rdm = newrandom()

local TEMP_VECTOR2 = Vector2.new()

-- Vehicle slide tuning:
-- tangential scale = how much forward motion is preserved while colliding not head-on.
-- outward bias = tiny push away from the surface to prevent sticky head-on contact.
local VEHICLE_SLIDE_TANGENT_SCALE = 1.08
local VEHICLE_SLIDE_OUTWARD_BIAS = 0.015
local VEHICLE_SLIDE_OUTWARD_BIAS_HEADON_DOT = 0.035
local VEHICLE_SLIDE_MIN_LEN_SQ = 0.00000005
local VEHICLE_COLLISION_RADIUS = 0.2
local VEHICLE_SLIDE_COLLISION_RADIUS = 0.14
local VEHICLE_SLIDE_GALLOP_MULT = 1.15


---@param state "walk"|"gallop"
---@return number
---@nodiscard
local function getSpeed(state)
    if state == "walk" then
        return SandboxVars.HorseMod.WalkSpeed ---@diagnostic disable-line
    else
        return SandboxVars.HorseMod.GallopSpeed ---@diagnostic disable-line
    end
end


---@deprecated Use getSpeed("walk"), getSpeed("gallop") instead.
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
    return t*t*(3 - 2*t)
end


---@param a number
---@param b number
---@param t number
---@return number
local function lerp(a, b, t)
    return a + (b - a) * t
end


---@deprecated Use getSquare(x, y, z) instead.
---@param x number
---@param y number
---@param z number
---@return IsoGridSquare | nil
---@nodiscard
local function getSq(x,y,z)
    return getCell():getGridSquare(math.floor(x), math.floor(y), z)
end


---@param treeMult number
---@return number
---@nodiscard
local function hedgeMultFromTree(treeMult)
    return 1.0 - (1.0 - treeMult) * 0.5
end


---@param square IsoGridSquare
---@return "tree" | "hedge" | "bush" | "none"
---@nodiscard
local function getVegetationTypeAt(square)
    local props = square:getProperties()

    local tree = square:getTree()
    local movementType = props:get("Movement")

    if tree and tree:getSize() > 2 then
        return "tree"
    elseif movementType == "HedgeLow" or movementType == "HedgeHigh" then
        return "hedge"
    elseif square and square:hasBush() then
        return "bush"
    end

    return "none"
end

-- CENTER blockers only (no WallN/WallW/Window* here!)
---@param sq IsoGridSquare | nil
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
        if properties and 
            (properties:get("Solid") or properties:get("SolidTrans")) then
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
            -- Cheap distance gate before running character-vs-vehicle collision.
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
    -- Use the collision push-out point to estimate a surface normal.
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

    -- keep tangential motion, only apply outward bias on near head-on impacts to reduce jitter while scraping
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
---@return IsoObject | nil
---@nodiscard
local function edgeHoppableBetween(a, b)
    local ax, ay = a:getX(), a:getY()
    local bx, by = b:getX(), b:getY()

    if by == ay then
        if bx == ax + 1 then
            -- moving EAST: use west edge of destination
            return b:getHoppable(false)
        elseif bx == ax - 1 then
            -- moving WEST: use west edge of origin
            return a:getHoppable(false)
        end
    elseif bx == ax then
        if by == ay + 1 then
            -- moving SOUTH: use north edge of destination
            return b:getHoppable(true)
        elseif by == ay - 1 then
            -- moving NORTH: use north edge of origin
            return a:getHoppable(true)
        end
    end

    return nil
end

-- Edge blockers (walls/windows/doors/fences)
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

    -- FENCE
    local hop = edgeHoppableBetween(fromSq, toSq)
    if hop and hop:isHoppable() then
        if horse and isJumping then
            return false
        else
            return true
        end
    end

    -- Walls / windows / closed doors
    if fromSq:isWallTo(toSq) or toSq:isWallTo(fromSq) 
            or fromSq:isWindowTo(toSq) or toSq:isWindowTo(fromSq) then
        return true
    end

    local door = fromSq:getDoorTo(toSq) ---@as IsoThumpable | IsoDoor | nil
    if door and not door:IsOpen() then
        return true
    end

    door = toSq:getDoorTo(fromSq) ---@as IsoThumpable | IsoDoor | nil
    if door and not door:IsOpen() then
        return true
    end

    return false
end

--- crossing helper: edge must be open and destination center must be free
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
---@return -1 | 0 | 1
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
    local stepLen = math.sqrt(ox*ox + oy*oy)

    local fx, fy = math.floor(x0), math.floor(y0)
    local rx, ry = dx, dy

    -- clamp vs vertical edges (X)
    if rx > 0 then
        if not canCross(fx, fy, fx+1, fy, z, horse, isJumping) then
            local boundary = fx + 1 - EDGE_PAD
            if x0 + rx > boundary then rx = math.max(0, boundary - x0) end
        end
    elseif rx < 0 then
        if not canCross(fx-1, fy, fx, fy, z, horse, isJumping) then
            local boundary = fx + EDGE_PAD
            if x0 + rx < boundary then rx = math.min(0, boundary - x0) end
        end
    end

    -- clamp vs horizontal edges (Y)
    if ry > 0 then
        if not canCross(fx, fy, fx, fy+1, z, horse, isJumping) then
            local boundary = fy + 1 - EDGE_PAD
            if y0 + ry > boundary then ry = math.max(0, boundary - y0) end
        end
    elseif ry < 0 then
        if not canCross(fx, fy-1, fx, fy, z, horse, isJumping) then
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
                if not canCross(fx, fy, fx+1, fy, z, horse, isJumping) then
                    local b = fx + 1 - EDGE_PAD
                    if x0 + px > b then px = math.max(0, b - x0) end
                end
            elseif px < 0 then
                if not canCross(fx-1, fy, fx, fy, z, horse, isJumping) then
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
                if not canCross(fx, fy, fx, fy+1, z, horse, isJumping) then
                    local b = fy + 1 - EDGE_PAD
                    if y0 + py > b then py = math.max(0, b - y0) end
                end
            elseif py < 0 then
                if not canCross(fx, fy-1, fx, fy, z, horse, isJumping) then
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
    local midSqX = (tx ~= fx) and getSquare(tx, fy, z) or nil
    local midSqY = (ty ~= fy) and getSquare(fx, ty, z) or nil
    local killedX, killedY = false, false
    if midSqX and squareCenterSolid(midSqX) then rx = 0; killedX = true end
    if midSqY and squareCenterSolid(midSqY) then ry = 0; killedY = true end

    -- axis projection if one axis killed
    if killedX and not killedY and ry ~= 0 then
        local py = signf(oy) * stepLen
        if py > 0 then
            if not canCross(fx, fy, fx, fy+1, z, horse, isJumping) then
                local b = fy + 1 - EDGE_PAD
                if y0 + py > b then py = math.max(0, b - y0) end
            end
        elseif py < 0 then
            if not canCross(fx, fy-1, fx, fy, z, horse, isJumping) then
                local b = fy + EDGE_PAD
                if y0 + py < b then py = math.min(0, b - y0) end
            end
        end
        if py ~= 0 and not centerBlocked(x0, y0 + py) then return 0, py else return 0, 0 end
    elseif killedY and not killedX and rx ~= 0 then
        local px = signf(ox) * stepLen
        if px > 0 then
            if not canCross(fx, fy, fx+1, fy, z, horse, isJumping) then
                local b = fx + 1 - EDGE_PAD
                if x0 + px > b then px = math.max(0, b - x0) end
            end
        elseif px < 0 then
            if not canCross(fx-1, fy, fx, fy, z, horse, isJumping) then
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
                      and canCross(fx, fy, tx, fy, z, horse, isJumping)
                      and canCross(tx, fy, tx, ty, z, horse, isJumping)
        local yFirstOk = (not midSqY or not squareCenterSolid(midSqY))
                      and canCross(fx, fy, fx, ty, z, horse, isJumping)
                      and canCross(fx, ty, tx, ty, z, horse, isJumping)
        if not xFirstOk and not yFirstOk then
            -- project onto best axis
            local px, py = signf(ox) * stepLen, signf(oy) * stepLen
            local rx1, ry1 = px, 0
            if rx1 > 0 then
                if not canCross(fx, fy, fx+1, fy, z, horse, isJumping) then
                    local b = fx + 1 - EDGE_PAD
                    if x0 + rx1 > b then rx1 = math.max(0, b - x0) end
                end
            elseif rx1 < 0 then
                if not canCross(fx-1, fy, fx, fy, z, horse, isJumping) then
                    local b = fx + EDGE_PAD
                    if x0 + rx1 < b then rx1 = math.min(0, b - x0) end
                end
            end
            local okX = (rx1 ~= 0) and not squareCenterSolid(getSquare(x0 + rx1, y0, z))

            local rx2, ry2 = 0, py
            if ry2 > 0 then
                if not canCross(fx, fy, fx, fy+1, z, horse, isJumping) then
                    local b = fy + 1 - EDGE_PAD
                    if y0 + ry2 > b then ry2 = math.max(0, b - y0) end
                end
            elseif ry2 < 0 then
                if not canCross(fx, fy-1, fx, fy, z, horse, isJumping) then
                    local b = fy + EDGE_PAD
                    if y0 + ry2 < b then ry2 = math.min(0, b - y0) end
                end
            end
            local okY = (ry2 ~= 0) and not squareCenterSolid(getSquare(x0, y0 + ry2, z))

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

--- Do all substeps in locals; write back ONCE.
---@param rider IsoPlayer
---@param horse IsoAnimal
---@param distance Vector2
---@param isGalloping boolean
---@param isJumping boolean
local function moveWithCollision(rider, horse, distance, isGalloping, isJumping)
    local z = horse:getZ()
    local x = horse:getX()
    local y = horse:getY()
    local candidates = {}

    local maxProbeDistance = math.sqrt(36) + distance:getLength() + 1
    local maxProbeDistanceSq = maxProbeDistance * maxProbeDistance
    -- Cache nearby vehicles once for this move call; reused by all substeps.
    local allVehicles = getCell():getVehicles()
    for i = 1, allVehicles:size() do
        local vehicle = allVehicles:get(i - 1)
        if vehicle and math.floor(vehicle:getZ()) == z then
            local dx = vehicle:getX() - x
            local dy = vehicle:getY() - y
            if (dx * dx + dy * dy) <= maxProbeDistanceSq then
                candidates[#candidates + 1] = vehicle
            end
        end
    end

    -- collision uses fixed time steps to maintain precision
    --  i'm kind of sceptical that this does anything though, this is really high
    --  you'd have to be running below 15fps for this to come into play 
    local maxStepDist = 0.065

    local remaining = distance:getLength()
    while remaining > 0 do
        local magnitude = math.min(remaining, maxStepDist)
        distance:setLength(magnitude)

        -- check if hitting a wall
        local rx, ry = collideStepAt(horse, z, x, y, distance:getX(), distance:getY(), isJumping)
        if rx == 0 and ry == 0 then
            if isGalloping then
                Mounting.dismountFallBack(rider, horse)
            end
            break
        end

        local nx = x + rx
        local ny = y + ry
        local hitVehicle, hitX, hitY = riderCollidesWithVehicleAt(rider, candidates, nx, ny, z, VEHICLE_COLLISION_RADIUS)
        if hitVehicle then
            -- Direct move hit vehicle: try moving along its surface (slide) first.
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
            local slideBlockedVehicle = riderCollidesWithVehicleAt(rider, candidates, snx, sny, z, VEHICLE_SLIDE_COLLISION_RADIUS)
            if slideBlockedVehicle or squareCenterSolid(getSquare(snx, sny, z)) then
                -- second chance with a shorter slide before giving up
                snx = x + sx * 0.6
                sny = y + sy * 0.6
                slideBlockedVehicle = riderCollidesWithVehicleAt(rider, candidates, snx, sny, z, VEHICLE_SLIDE_COLLISION_RADIUS)
                if slideBlockedVehicle or squareCenterSolid(getSquare(snx, sny, z)) then
                    -- third chance on the opposite side helps with diagonal vehicle corners
                    snx = x - sx * 0.6
                    sny = y - sy * 0.6
                    slideBlockedVehicle = riderCollidesWithVehicleAt(rider, candidates, snx, sny, z, VEHICLE_SLIDE_COLLISION_RADIUS)
                    if slideBlockedVehicle or squareCenterSolid(getSquare(snx, sny, z)) then
                        break
                    end
                end
            end

            nx = snx
            ny = sny
        end

        if squareCenterSolid(getSquare(nx, ny, z)) then
            break
        end

        x = nx
        y = ny
        remaining = remaining - magnitude
    end

    -- Single commit per frame
    horse:setX(x)
    horse:setY(y)
end


---@param current number
---@param target number
---@param amount number
---@return number
local function approach(current, target, amount)
    local delta = target - current
    if delta > 0 then
        ---@type number
        local step = math.min(delta, amount)
        return current + step
    else
        local step = math.max(delta, -amount)
        return current + step
    end
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


local TROT_MULT  = 1.1

local TREES_GENE_MULT_WALK = 0.40   -- 65% of base when walking/trotting in trees
local TREES_GENE_MULT_RUN  = 0.25   -- 55% of base when galloping in trees
local TREES_LINGER_SECONDS = 1.0   -- keep slowdown for 1s after leaving trees


-- low value causes player to turn before horse which causes animation desync
-- no noticeable performance impact from having it high
local TURN_STEPS_PER_SEC = 60


local PLAYER_SYNC_TUNER = 0.8

---@namespace HorseMod


---Handles the movement aspect of the player mounting horse state.
---@class MountController
---
---@field mount Mount
---
---How much of a turn is 'saved up'
---@field turnAcceleration number
---
---Whether the most recent turn was a right turn
---@field lastTurnWasRight boolean
---
---Slowdown time remaining from vegetation.
---@field vegetationLingerTime number
---
---Speed multiplier from last vegetation.
---@field vegetationLingerStartMult number
---
---Current movement speed in square/s.
---@field speed number
---
---Used to calculate if the player should fall while in trees. Chance increases the longer they stay in trees.
---@field timeInTrees number
---
---Last time a tree fall check was made.
---@field lastCheck number
---
---Amount of slowdown applied by hitting zombies.
---@field slowdownCounter number
---
---Indicates whether the pair can turn this update.
---@field doTurn boolean
---
---Force gallop. Used for jmping notably.
---@field forcedInput InputManager.Input
local MountController = {}
MountController.__index = MountController


local BASE_CHANCE = 0.1
local NIMBLE_LOW = 1
local NIMBLE_HIGH = 0
local TRAITS = {
    [CharacterTrait.EAGLE_EYED] = 0.5,
    [CharacterTrait.GYMNAST] = 0.5,
    [CharacterTrait.MOTION_SENSITIVE] = 2,
    [CharacterTrait.CLUMSY] = 2,
}

---@return number
function MountController:calculateTreeFallChance()
    local rider = self.mount.pair.rider

    local timeInTrees = self.timeInTrees
    local skill = rider:getPerkLevel(Perks.Nimble)

    local chance = BASE_CHANCE * timeInTrees * ((NIMBLE_HIGH - NIMBLE_LOW) / 10 * skill + NIMBLE_LOW)

    for trait, mult in pairs(TRAITS) do
        if rider:hasTrait(trait) then
            chance = chance * mult
        end
    end

    return chance
end

---@return boolean
function MountController:rollForTreeFall()
    local chance = self:calculateTreeFallChance()
    local pass = rdm:random() < chance
    if pass then
        local pair = self.mount.pair
        Mounting.dismountFallBack(pair.rider, pair.mount)
        return true
    end
    return false
end

---Maximum seconds of slowdown that can be accrued.
---@readonly
---@type number
local SLOWDOWN_MAX = 2.5

---Amount to increment the slowdown counter when hitting a zombie.
---@readonly
---@type number
local SLOWDOWN_ZOMBIE_KNOCKDOWN_INCREASE = 0.75

---Amount to increment the slowdown counter per second when near a zombie but not fast enough to knock it down.
---@readonly
---@type number
local SLOWDOWN_ZOMBIE_NEARBY_INCREASE = 4

---Amount to increment the slowdown counter per second when trampling a zombie on the ground.
---@readonly
---@type number
local SLOWDOWN_ZOMBIE_GROUND_INCREASE = 2

---Minimum seconds of slowdown before the horse is actually slowed.
---@readonly
---@type number
local SLOWDOWN_MIN_SECONDS = 1

---Maximum seconds of slowdown where slowdown amount stops increasing.
---@readonly
---@type number
local SLOWDOWN_MAX_SECONDS = 2

---Scalar to movement speed when at maximum slowdown.
---The final speed scalar is interpolated based on the current slowdown value (between ZOMBIE_SLOWDOWN_MIN_SECONDS and ZOMBIE_SLOWDOWN_MAX_SECONDS)
---from 1 to this value.
---@readonly
---@type number
local SLOWDOWN_MAX_SCALAR = 0.2

---Minimum speed to reduce the speed to from slowdown.
---Used because very low scalars needed to make galloping slow enough make slower speeds ridiculously slow.
---@readonly
---@type number
local SLOWDOWN_MIN_SPEED = 2

---Minimum speed required to knock down a zombie.
---@readonly
---@type number
local KNOCKDOWN_MIN_SPEED = 6.5

---@param deltaTime number
function MountController:updateSlowdown(deltaTime)
    self.slowdownCounter = math.max(self.slowdownCounter - deltaTime, 0)

    -- TODO: check neighbouring squares too since the horse is big
    local square = self.mount.pair.mount:getSquare()

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
                    local facingSameDir = math.abs(zombie:getDirectionAngle() - self.mount.pair.mount:getDirectionAngle()) <= 180
                    -- TODO: probably needs to be sent to the server
                    zombie:knockDown(facingSameDir)
                else
                    self.slowdownCounter = self.slowdownCounter + SLOWDOWN_ZOMBIE_NEARBY_INCREASE * deltaTime
                end
            end
        end
    end

    self.slowdownCounter = math.min(self.slowdownCounter, SLOWDOWN_MAX)
end


---@param input InputManager.Input
---@param deltaTime number
function MountController:turn(input, deltaTime)
    local currentDirection = self.mount.pair.mount:getDir()

    local targetDirection = nil
    if input.movement.x ~= 0 or input.movement.y ~= 0 then
        targetDirection = IsoDirections.fromAngle(input.movement.x, input.movement.y):RotLeft()
    else
        targetDirection = currentDirection
    end

    self.turnAcceleration = self.turnAcceleration + deltaTime * TURN_STEPS_PER_SEC

    -- negative if left turn, positive if right turn
    local turnDistance = currentDirection:compareTo(targetDirection)

    local absoluteTurnDistance = math.abs(turnDistance)
    if absoluteTurnDistance > 4 then
        turnDistance = (-turnDistance + 4) % 8
    end

    local turns = math.min(
        math.floor(self.turnAcceleration),
        absoluteTurnDistance
    )

    local shouldTurnRight = self.lastTurnWasRight
    if turnDistance == 0 then
        turns = 0
        self.turnAcceleration = 0
    elseif absoluteTurnDistance ~= 4 then
        -- we don't want to change turning direction during a 180
        shouldTurnRight = turnDistance > 0
    else
        local rider = self.mount.pair.rider
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

    -- lock both to the same stepped direction
    self.mount.pair:setDirection(currentDirection)
end


---@param input InputManager.Input
---@param deltaTime number
---@return number
function MountController:getVegetationEffect(input, deltaTime)
    local vegetationType = getVegetationTypeAt(self.mount.pair.rider:getSquare())

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
    else
        if self.vegetationLingerTime <= 0 then
            return 1.0
        end

        local p = 1.0 - (self.vegetationLingerTime / TREES_LINGER_SECONDS)
        local eased = smoothstep(p)

        self.vegetationLingerTime = math.max(0, self.vegetationLingerTime - deltaTime)

        return lerp(self.vegetationLingerStartMult, 1.0, eased)
    end
end


---Mounted animation walk speed.
---@readonly
---@type number
local ANIMATION_SPEED_WALK = 1.5

---Mounted walk speed.
---@readonly
---@type number
local SPEED_WALK = 1.6

---Mounted trot speed.
---@readonly
---@type number
local SPEED_TROT = 4

---Mounted gallop speed.
---@readonly
---@type number
local SPEED_GALLOP = 8.5

---Rate to approach a higher target speed in squares/s.
---@readonly
---@type number
local ACCELERATION_RATE = 12

---Rate to approach a lower target speed in squares/s.
---@readonly
---@type number
local DECELERATION_RATE = 6

---Speed needed to turn as a factor of the movement type (walk, trot, gallop)'s base speed.
---@readonly
---@type number
local SPEED_FACTOR_TURN = 0.8


---@param input InputManager.Input
---@return number
---@nodiscard
function MountController:getTargetSpeed(input)
    if input.run then
        return SPEED_GALLOP * math.max(getSpeed("gallop") * Stamina.runSpeedFactor(self.mount.pair.mount), 0.35)
    elseif self.mount.pair.mount:getVariableBoolean(AnimationVariable.TROT) then
        return SPEED_TROT * getSpeed("walk")
    else
        return SPEED_WALK * getSpeed("walk")
    end
end


---@param input InputManager.Input
---@param deltaTime number
---@param isJumping boolean
function MountController:updateSpeed(input, deltaTime, isJumping)
    self:updateSlowdown(deltaTime)

    local walkMultiplier = getSpeed("walk")
    local gallopRawSpeed = getSpeed("gallop")

    local pair = self.mount.pair
    local mount = pair.mount
    local rider = pair.rider

    -- vegetation slowdown is applied through gene speed?
    local geneSpeed = getGeneticSpeed(mount) * self:getVegetationEffect(input, deltaTime)

    pair:setAnimationVariable(AnimationVariable.GENE_SPEED, geneSpeed)

    mount:setVariable(AnimationVariable.WALK_SPEED, walkMultiplier * ANIMATION_SPEED_WALK)
    mount:setVariable(AnimationVariable.TROT_SPEED,  walkMultiplier * TROT_MULT)
    mount:setVariable(AnimationVariable.RUN_SPEED, gallopRawSpeed)

    rider:setVariable(AnimationVariable.WALK_SPEED, walkMultiplier * PLAYER_SYNC_TUNER * ANIMATION_SPEED_WALK)
    rider:setVariable(AnimationVariable.TROT_SPEED,  walkMultiplier * TROT_MULT * PLAYER_SYNC_TUNER)
    rider:setVariable(AnimationVariable.RUN_SPEED, gallopRawSpeed * PLAYER_SYNC_TUNER)

    local target = 0.0

    local moving = (input.movement.x ~= 0 or input.movement.y ~= 0)
    if moving then
        target = self:getTargetSpeed(input)
    elseif mount:isTurning() then
        target = self:getTargetSpeed(input) * SPEED_FACTOR_TURN
    end

    target = target * self:getVegetationEffect(input, deltaTime)

    local rate = (target > self.speed) and ACCELERATION_RATE or DECELERATION_RATE

    self.speed = approach(self.speed, target, rate * deltaTime)

    if self.speed > SLOWDOWN_MIN_SPEED then
        if self.slowdownCounter >= SLOWDOWN_MIN_SECONDS then
            local slowdownAmount = math.min(math.max(self.slowdownCounter - SLOWDOWN_MIN_SECONDS, 0), SLOWDOWN_MAX_SECONDS - SLOWDOWN_MIN_SECONDS)
            local slowdownScalar = PZMath.lerp(1, SLOWDOWN_MAX_SCALAR, slowdownAmount / (SLOWDOWN_MAX_SECONDS - SLOWDOWN_MIN_SECONDS))
            self.speed = math.min(self.speed, target * slowdownScalar)
        end

        self.speed = math.max(self.speed, SLOWDOWN_MIN_SPEED)
    end

    if self.speed < 0.01 then
        self.speed = 0
    end
end

function MountController:updateTreeFall(isGalloping, deltaTime)
    local rider = self.mount.pair.rider

    -- make the player fall if they are in trees based on some skills and traits
    local timeInTrees = self.timeInTrees
    if isGalloping then
        if rider:isInTreesNoBush() 
            or self.mount.pair.mount:isInTreesNoBush() then
            self.timeInTrees = timeInTrees + deltaTime

            -- roll for tree fall every 0.5s
            if self.lastCheck > 0.5 then
                self:rollForTreeFall()
                self.lastCheck = 0.0
            else
                self.lastCheck = self.lastCheck + deltaTime
            end
        end

    -- we consider the player to be unbalanced when exiting trees for a short time
    -- so the counter isn't reset immediately
    elseif self.timeInTrees > 0 then
        timeInTrees = math.max(0, timeInTrees - deltaTime*4)
        timeInTrees = math.min(timeInTrees, 10)
        self.timeInTrees = timeInTrees
    end
end

---@alias MovementState "idle"|"walking"|"trot"|"gallop"

---@return MovementState
function MountController:getMovementState()
    if self.speed <= 0.01 then
        return "idle"
    elseif self.mount.pair:getAnimationVariableBoolean(AnimationVariable.GALLOP) then
        return "gallop"
    elseif self.mount.pair:getAnimationVariableBoolean(AnimationVariable.TROT) then
        return "trot"
    else
        return "walking"
    end
end


function MountController:toggleTrot()
    local current = self.mount.pair:getAnimationVariableBoolean(AnimationVariable.TROT)
    self.mount.pair:setAnimationVariable(AnimationVariable.TROT, not current)
end

---Real speed in distance per second. Needed because `getMovementSpeed` is per tick.
---@deprecated use the speed field instead.
---@return number
function MountController:getCurrentSpeed()
    return self.speed
end


---Checks whenever the mount can jump.
---@return boolean
function MountController:canJump()
    local mount = self.mount.pair.mount
    return mount:getVariableBoolean(AnimationVariable.GALLOP)
        and self:getCurrentSpeed() > 6
        and not self.mount.pair:getAnimationVariableBoolean(AnimationVariable.JUMP)
end

---Checks if the current action is jumping.
---@return boolean
function MountController:isJumping()
    local pair = self.mount.pair
    local queue = ISTimedActionQueue.getTimedActionQueue(pair.rider)
    local current = queue.current
    if not current then return false end
    return current.Type == HorseJump.Type
end

---Initiates a jump action.
function MountController:jump()
    local rider = self.mount.pair.rider
    
    -- reset the queue of actions, since jump takes priority
    ISTimedActionQueue.clear(rider)    
    ISTimedActionQueue.add(HorseJump:new(rider, self.mount.pair.mount, self))
end


---@param input InputManager.Input
function MountController:update(input)
    assert(self.mount.pair.rider:getVariableString(AnimationVariable.RIDING_HORSE) == "true")

    local forcedInput = self.forcedInput
    input = forcedInput or input

    local mountPair = self.mount.pair
    local rider = mountPair.rider
    local mount = mountPair.mount

    rider:setSneaking(false)
    rider:setIgnoreAutoVault(true)

    mount:getPathFindBehavior2():reset()
    mount:setVariable("bPathfind", false)

    local deltaTime = GameTime.getInstance():getTimeDelta()
    local moving = (input.movement.x ~= 0 or input.movement.y ~= 0)
    local isGalloping = self:getMovementState() == "gallop"

    -- Prevent running at zero stamina
    if not Stamina.shouldRun(mount, input, moving) then
        input.run = false
    else
        input.run = true
    end

    -- verify that the horse isn't in a jumping animation before turning
    local doTurn = self.doTurn
    local isJumping = self:isJumping()

    -- safeguard in case the jump action errored out, not resetting the doTurn flag
    if not isJumping then
        self.doTurn = true
    end

    -- update current movement
    if doTurn then
        self:turn(input, deltaTime)
    end
    self:updateSpeed(input, deltaTime, isJumping)

    if self.speed > 0
        and not rider:getVariableBoolean(AnimationVariable.DISMOUNT_STARTED) then
        local currentDirection = nil

        -- albion: HACK: i don't know why, but animForwardDirection makes falling off when you hit a wall not work
        -- but using getDir() all the time prevents the turning circle from working
        if mount:isTurning() then
            currentDirection = mount:getAnimForwardDirection(TEMP_VECTOR2)
        else
            currentDirection = mount:getDir():ToVector(TEMP_VECTOR2)
        end

        local velocity = currentDirection:setLength(self.speed * deltaTime)
        moveWithCollision(rider, mount, velocity, isGalloping, isJumping)

        mount:setVariable("animalWalking", not input.run)
        mountPair:setAnimationVariable(AnimationVariable.GALLOP, input.run)
    else
        mountPair:setAnimationVariable(AnimationVariable.GALLOP, false)
        mount:setVariable("animalWalking", false)
    end

    ---@type string[]
    local mirrorVarsMount =  { "HorseGalloping","isTurningLeft","isTurningRight","walkstateRun" }
    for i = 1, #mirrorVarsMount do
        local k = mirrorVarsMount[i]
        local v = mount:getVariableBoolean(k)
        if rider:getVariableBoolean(k) ~= v then
            rider:setVariable(k, v)
        end
    end

    ---@type string[]
    local mirrorVarsRider =  { "IdleToRun" }
    for i = 1, #mirrorVarsRider do
        local k = mirrorVarsRider[i]
        local v = rider:getVariableBoolean(k)
        if mount:getVariableBoolean(k) ~= v then
            mount:setVariable(k, v)
        end
    end

    rider:setX(mount:getX())
    rider:setY(mount:getY())
    rider:setZ(mount:getZ())

    self:updateTreeFall(isGalloping, deltaTime)

    -- verify the rider/mount are not falling
    ---@TODO improve by having a custom falling animation for the player
    if rider:isbFalling() or mount:isbFalling() then
        Mounting.dismountFall(rider, mount)
    end
end


---@param mount Mount
---@return self
---@nodiscard
function MountController.new(mount)
    return setmetatable(
        {
            mount = mount,
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
        },
        MountController
    )
end


return MountController
