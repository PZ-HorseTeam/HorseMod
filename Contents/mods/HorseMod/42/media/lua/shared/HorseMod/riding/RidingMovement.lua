---@namespace HorseMod
-- RidingMovement.lua
-- Handles all movement physics and behavior for mounted horse riding
-- Includes collision detection, animation state management, and player input processing

local Stamina = require("HorseMod/Stamina")
local AnimationVariable = require("HorseMod/definitions/AnimationVariable")
local MountedAnimationState = require("HorseMod/riding/MountedAnimationState")
local MountedDirection = require("HorseMod/riding/MountedDirection")

local rdm = newrandom()  -- Random number generator for probabilistic events
local TEMP_VECTOR2 = Vector2.new()  -- Reusable vector for calculations
local SPEED_VECTOR2 = Vector2.new()  -- Reusable vector for speed calculations

-- Vehicle collision sliding parameters
local VEHICLE_SLIDE_TANGENT_SCALE = 1.08  -- How much movement is maintained along the collision tangent
local VEHICLE_SLIDE_OUTWARD_BIAS = 0.015  -- Pushes the rider away from vehicle during collision tangent
local VEHICLE_SLIDE_OUTWARD_BIAS_GALLOP = 0.03
local VEHICLE_SLIDE_OUTWARD_BIAS_HEADON_DOT = 0.035  -- Threshold for head-on collisions
local VEHICLE_SLIDE_MIN_LEN_SQ = 0.00000005  -- Minimum slide distance squared
local VEHICLE_COLLISION_RADIUS = 0.2  -- Collision radius for initial vehicle detection
local VEHICLE_SLIDE_COLLISION_RADIUS = 0.14  -- Smaller collision radius for slide path
local VEHICLE_SLIDE_GALLOP_MULT = 1.3  -- Extra slide velocity when galloping

-- Wall collision detection
-- Sets the angle that is considered wall collision, allowing sliding against walls at wider angles
-- 0.25 = sin^2(30deg), meaning walls are hit at 30 degree angles or shallower
local WALL_HIT_MIN_PROGRESS_FRACTION = 0.25

-- Get the configured base speed for a movement state
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

-- Get the horse's genetic speed modifier
---@param horse IsoAnimal
---@return number
---@nodiscard
local function getGeneticSpeed(horse)
    return horse:getUsedGene("speed"):getCurrentValue()
end

-- Smooth interpolation function (Hermite interpolation) for easing values 0-1
-- Creates smoother transitions than linear interpolation
---@param t number
---@return number
---@nodiscard
local function smoothstep(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    return t * t * (3 - 2 * t)
end

-- Linear interpolation between two values
---@param a number
---@param b number
---@param t number between 0 and 1
---@return number
---@nodiscard
local function lerp(a, b, t)
    return a + (b - a) * t
end

-- Get grid square at world coordinates (floors to integer grid position)
---@param x number
---@param y number
---@param z number
---@return IsoGridSquare?
---@nodiscard
local function getSq(x, y, z)
    return getCell():getGridSquare(math.floor(x), math.floor(y), z)
end

-- Maximum vertical step per frame - prevents horse from falling rapidly when descending stairs
local VERTICAL_FOLLOW_MAX_STEP = 0.95

-- Grace period for ramp/slope detection - gives the horse time to avoid false fall detection
-- when transitioning between stair sections (sometimes counts as airborne for a few frames)
local RAMP_FALL_GRACE_SECONDS = 0.4

-- Find the ground square beneath the horse (handles stairs, ramps, and floors)
-- Searches downward for a valid floor surface and returns the closest one
-- Used to follow stair height and determine collision Z level
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

-- Check if a square is a ramp or staircase (sloped surface)
---@param square IsoGridSquare
---@return boolean
---@nodiscard
local function squareIsRamp(square)
    return square:HasStairs() or square:hasSlopedSurface()
end

-- Convert tree movement multiplier to hedge multiplier
-- Hedges have less movement penalty than trees (50% of the tree penalty)
---@param treeMult number
---@return number
---@nodiscard
local function hedgeMultFromTree(treeMult)
    return 1.0 - (1.0 - treeMult) * 0.5
end

-- Identify vegetation type at a square (trees, hedges, bushes) for movement penalties
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

-- Check if rider collides with any vehicles at a given position
-- Returns collision status and the collision point coordinates
---@param rider IsoPlayer
---@param vehicle BaseVehicle
---@param worldX number
---@param worldY number
---@param collisionRadius number
---@return boolean collided
---@return number? hitX collision point X
---@return number? hitY collision point Y
---@nodiscard
local function riderCollidesWithVehicleAt(rider, vehicle, worldX, worldY, collisionRadius)
    -- Temporarily set rider position to test collision
    local oldNextX = rider:getNextX()
    local oldNextY = rider:getNextY()
    rider:setNextX(worldX)
    rider:setNextY(worldY)

    local collided = false
    if vehicle:testCollisionWithCharacter(rider, collisionRadius, TEMP_VECTOR2) then
        collided = true
    end
    
    if not collided then
        return false, nil, nil
    end

    -- Restore rider position and return collision results
    local hitX, hitY = TEMP_VECTOR2:getX(), TEMP_VECTOR2:getY()
    rider:setNextX(oldNextX)
    rider:setNextY(oldNextY)

    -- this is something they do in the Java
    -- they set hitX and hitY to 1.0 in some specific condition
    -- and that is considered as no collision
    if (hitX == 1.0 and hitY == 1.0) then
        return false, nil, nil
    end

    return collided, hitX, hitY
end


---Retrieves the slide delta vector when colliding with a vehicle surface.
---@param worldX number
---@param worldY number
---@param moveX number
---@param moveY number
---@param collisionX number
---@param collisionY number
---@return number
---@return number
---@nodiscard
local function getVehicleSlideDelta(isGalloping, worldX, worldY, moveX, moveY, collisionX, collisionY)
    -- the collision point drawn to the horse position
    -- is the normal vector of the vehicle surface
    local normalX = collisionX - worldX
    local normalY = collisionY - worldY
    local normalLen = math.sqrt(normalX * normalX + normalY * normalY)
    if normalLen <= 0.0001 then
        return 0, 0
    end

    local tangentX = -normalY
    local tangentY = normalX
    local tangentDot = moveX * tangentX + moveY * tangentY

    -- this is to prevent clipping through the vehicle
    local outwardBias = 0.0
    if isGalloping then
        outwardBias = VEHICLE_SLIDE_OUTWARD_BIAS_GALLOP
    else
        outwardBias = VEHICLE_SLIDE_OUTWARD_BIAS
    end

    -- calculate the slide vector along the tangent and outward bias
    local slideX = tangentX * tangentDot * VEHICLE_SLIDE_TANGENT_SCALE + normalX * outwardBias / normalLen
    local slideY = tangentY * tangentDot * VEHICLE_SLIDE_TANGENT_SCALE + normalY * outwardBias / normalLen

    -- no need to move for very small slide distances
    if (slideX * slideX + slideY * slideY) <= VEHICLE_SLIDE_MIN_LEN_SQ then
        return 0, 0
    end

    -- apply gallop slowdown factor to the slide
    if isGalloping then
        slideX = slideX * VEHICLE_SLIDE_GALLOP_MULT
        slideY = slideY * VEHICLE_SLIDE_GALLOP_MULT
    end

    return slideX, slideY
end

-- Check for hoppable objects (fences, gates) between two adjacent squares
-- Returns the hoppable object if one exists that the horse can jump over
---@param a IsoGridSquare
---@param b IsoGridSquare
---@return IsoObject?
---@nodiscard
local function edgeHoppableBetween(a, b)
    local ax, ay = a:getX(), a:getY()
    local bx, by = b:getX(), b:getY()

    -- Check horizontal movement (false = not vertical)
    if by == ay then
        if bx == ax + 1 then
            return b:getHoppable(false)
        elseif bx == ax - 1 then
            return a:getHoppable(false)
        end
    -- Check vertical movement (true = vertical)
    elseif bx == ax then
        if by == ay + 1 then
            return b:getHoppable(true)
        elseif by == ay - 1 then
            return a:getHoppable(true)
        end
    end

    return nil
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

-- Tree and vegetation movement constants
local TREES_GENE_MULT_WALK = 0.40  -- Movement penalty when walking through trees (40% speed)
local TREES_GENE_MULT_RUN = 0.25   -- Movement penalty when galloping through trees (25% speed)
local TREES_LINGER_SECONDS = 1.0   -- How long to apply tree penalty after leaving trees
local TURN_STEPS_PER_SEC = 60  -- How fast the horse can turn
local JUMP_SECONDS = 0.85  -- Duration of jump animation
local JUMP_COOLDOWN_SECONDS = 1.4  -- Cooldown between consecutive jumps
local IDLE_TO_RUN_SECONDS = 0.6  -- Duration of idle-to-gallop transition animation

-- Tree fall chance constants (when galloping through trees, rider might fall off)
local BASE_CHANCE = 0.1  -- Base probability per check
local NIMBLE_LOW = 1  -- Nimble skill minimum multiplier
local NIMBLE_HIGH = 0  -- Nimble skill maximum multiplier (lower = less likely to fall)
-- Trait modifiers for fall chance (1=no effect, <1=less likely, >1=more likely)
local TRAITS = {
    [CharacterTrait.EAGLE_EYED] = 0.5,     -- Better awareness reduces falls
    [CharacterTrait.GYMNAST] = 0.5,        -- Better coordination reduces falls
    [CharacterTrait.MOTION_SENSITIVE] = 2, -- Sensitive to motion increases falls
    [CharacterTrait.CLUMSY] = 2,           -- Clumsiness increases falls
}

-- Slowdown from nearby zombies (slows horse movement)
local SLOWDOWN_MAX = 2.5  -- Maximum slowdown counter
local SLOWDOWN_ZOMBIE_KNOCKDOWN_INCREASE = 0.75  -- When knocking down a zombie
local SLOWDOWN_ZOMBIE_NEARBY_INCREASE = 4  -- When zombie is simply nearby
local SLOWDOWN_ZOMBIE_GROUND_INCREASE = 2  -- When zombie is on ground crawling
local SLOWDOWN_MIN_SECONDS = 1  -- Minimum slowdown duration
local SLOWDOWN_MAX_SECONDS = 2  -- Maximum slowdown duration
local SLOWDOWN_MAX_SCALAR = 0.2  -- Maximum speed reduction (80% slowdown)
local SLOWDOWN_MIN_SPEED = 2  -- Minimum speed before slowdown applies
local KNOCKDOWN_MIN_SPEED = 6.5  -- Speed required to knockdown zombies

-- Movement speeds
local SPEED_WALK = 1.6  -- Walking speed
local SPEED_TROT = 4  -- Trotting speed (medium gait)
local SPEED_GALLOP = 8.5  -- Galloping speed
local ACCELERATION_RATE = 12  -- How quickly horse accelerates
local DECELERATION_RATE = 9  -- How quickly horse decelerates
local SPEED_FACTOR_TURN = 0.8  -- Reduce speed while turning
local TURN_ANIM_HOLD_SECONDS = 0.20  -- How long to hold turn animation

-- Input state for mounted movement
---@class RidingMovementInput
---@field movement {x: number, y: number}  -- Directional input (-1 to 1)
---@field run boolean  -- Whether player is requesting gallop
---@field trot boolean  -- Whether in trot mode
---@field jump boolean  -- Whether jump input is pressed
---@field hasReins boolean?  -- Whether rider is holding reins

-- Effect callbacks for movement events
---@class RidingMovementEffects
---@field authoritative boolean  -- Whether this instance has authority to make decisions
---@field onGallopBlocked fun(rider: IsoPlayer, horse: IsoAnimal)?  -- Called when gallop is blocked by obstacle
---@field onTreeFall fun(rider: IsoPlayer, horse: IsoAnimal)?  -- Called when rider falls from tree
---@field onFallDetected fun(rider: IsoPlayer, horse: IsoAnimal)?  -- Called when detecting a fall

-- Main movement controller for mounted riding
---@class RidingMovement
---@field pair MountPair  -- The rider and horse pair
---@field effects RidingMovementEffects  -- Event callbacks
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


---Precalculate the squares to check during the cast using Amanatides algorithm [1, 2].
---
---[1] http://www.cse.yorku.ca/~amana/research/grid.pdf
---
---[2] https://m4xc.dev/articles/amanatides-and-woo/
---@param x0 number
---@param y0 number
---@param z0 number
---@param vector Vector2
---@return {x: number, y: number, z: number}[]
local function getSquaresAmanatides(x0, y0, z0, vector)
    local square_points = {}

    -- cache
    local vx, vy = vector:getX(), vector:getY()

    -- skip if no movement
    local vlen = math.sqrt(vx * vx + vy * vy)
    if vlen == 0 then return {} end
    
    -- normalize the direction vector
    vx = vx / vlen
    vy = vy / vlen

    -- initialize step directions
    local stepX = vx > 0 and 1 or -1
    local stepY = vy > 0 and 1 or -1

    -- calculate delta t values (parametric distance between grid lines)
    local tDeltaX = (vx ~= 0) and (1 / math.abs(vx)) or math.huge
    local tDeltaY = (vy ~= 0) and (1 / math.abs(vy)) or math.huge

    -- start in grid cell
    local i = math.floor(x0)
    local j = math.floor(y0)
    
    -- calculate initial tMax values
    local tMaxX, tMaxY
    if stepX > 0 then
        tMaxX = (i + 1 - x0) * tDeltaX
    else
        tMaxX = (x0 - i) * tDeltaX
    end
    
    if stepY > 0 then
        tMaxY = (j + 1 - y0) * tDeltaY
    else
        tMaxY = (y0 - j) * tDeltaY
    end

    -- track the parametric distance traveled
    local t = 0.0

    -- traverse grid cells
    while t < vlen do
        table.insert(square_points, {x=i, y=j, z=z0})

        -- step to next grid cell
        if tMaxX < tMaxY then
            t = tMaxX
            i = i + stepX
            tMaxX = tMaxX + tDeltaX
        else
            t = tMaxY
            j = j + stepY
            tMaxY = tMaxY + tDeltaY
        end
    end

    return square_points
end


---@param horse IsoAnimal
---@param nx number
---@param ny number
local function updatePosition(horse, nx, ny)
    -- print(horse:getSquare(), nx, ny)
    horse:setX(nx)
    horse:setY(ny)
end


-- Move the horse/rider with collision detection against terrain, walls, doors, and vehicles
-- Handles smooth collision sliding and multi-step movement
---@param rider IsoPlayer
---@param horse IsoAnimal
---@param distance Vector2
---@param isGalloping boolean
---@param isJumping boolean
---@param effects RidingMovementEffects
local function moveWithCollision(rider, horse, distance, isGalloping, isJumping, effects)
    -- current position of the horse
    local x = horse:getX()
    local y = horse:getY()
    local horseZ = horse:getZ()
    local baseZ = math.floor(horseZ)

    -- theorical next position if no collision occurs
    local vx, vy = distance:getX(), distance:getY()
    local nx, ny = x + vx, y + vy

    -- we extend a bit the distance to make sure we check all squares the horse will pass through
    -- this is needed because the player can do micro movements that should be blocked, but not
    -- large enough so that the appropriate squares are not retrieved
    -- it sounds like an inacuracy with the speed ?
    local distanceLonger = Vector2.new(distance)
    distanceLonger:setLength(distanceLonger:getLength() + EDGE_PAD)

    -- retrieve squares the horse will pass through during its movement
    local squares = getSquaresAmanatides(x, y, horseZ, distanceLonger)

    -- if only one square, it means the horse won't change square
    -- so it can't collide with any tiles
    if #squares <= 1 then
        updatePosition(horse, nx, ny)
        return
    end

    -- else we need to check for collision

    -- this could work but the problem is that it returns true when moving alongside
    -- the surface, so we shouldn't fall in this case, we need more precision
    -- local isClear = LosUtil.lineClearCollide(x, y, horseZ, nx, ny, horseZ, false)

    -- identify which directions are blocked manually (reuses some of the logics from lineClearCollide)
    local isTileBlocked = false
    ---@type {from: IsoGridSquare, to: IsoGridSquare, deltaX: number, deltaY: number}[]
    local blockingSquares = {}
    for i = 1, #squares - 1 do
        local a = squares[i] --[[@as {x: number, y: number, z: number}]]
        local b = squares[i + 1] --[[@as {x: number, y: number, z: number}]]
        local fromSq = getSquare(a.x, a.y, a.z)
        local toSq = getSquare(b.x, b.y, b.z)
        if fromSq and toSq then
            -- first check for walls
            local blocked = fromSq:CalculateCollide(toSq, false, false, false, false)

            -- secondly, check for doors
            if not blocked then
                blocked = fromSq:isDoorBlockedTo(toSq)
            end

            if blocked then
                isTileBlocked = true
                -- the idea is that we keep previous blocked squares directions
                -- but also check if blocked in other directions to handle corners
                local deltaX = b.x - a.x
                local deltaY = b.y - a.y
                blockingSquares[#blockingSquares + 1] = {
                    from=fromSq, to=toSq,
                    deltaX=deltaX, deltaY=deltaY, -- directional information
                    }
            end
        else
            isTileBlocked = true
            break
        end
    end

    -- find a vehicle collision along the path, if any
    local allVehicles = getCell():getVehicles()
    local isVehicleBlocked, hitX, hitY
    if allVehicles then
        local it = allVehicles:iterator()
        while it:hasNext() do
            local vehicle = it:next()
            if vehicle:isCharacterAdjacentTo(horse) then
                -- Only include vehicles on same Z level and within probe distance
                if vehicle and math.floor(vehicle:getZ()) == baseZ then
                    isVehicleBlocked, hitX, hitY = riderCollidesWithVehicleAt(rider, vehicle, nx, ny, VEHICLE_COLLISION_RADIUS)
                    if isVehicleBlocked then
                        break
                    end
                end
            end
        end
    end

    -- not blocked, don't bother with anything else, simply move the horse
    if not isTileBlocked and not isVehicleBlocked then
        updatePosition(horse, nx, ny)
        return
    end

    -- now that we know we are blocked, we need to check if we can jump over the obstacle
    if isJumping and not isVehicleBlocked then
        -- check the blocking squares for hoppable objects between them
        for i = 1, #blockingSquares do
            local block = blockingSquares[i]
            local hop = edgeHoppableBetween(block.from, block.to)
            if hop and hop:isHoppable() then
                -- we can jump over this object, so allow the jump
                updatePosition(horse, nx, ny)
                return
            end
        end
    end

    -- should dismount because galloping while blocked is not allowed
    ---@FIXME need to ignore when riding at a specific angle from the wall, see WALL_HIT_MIN_PROGRESS_FRACTION
    if isGalloping and isTileBlocked and effects.onGallopBlocked then
        effects.onGallopBlocked(rider, horse)
    end

    -- we need to hug the wall, the coordinates should not be exactly the
    -- wall position or the horse can just clip through from top side
    -- that means we adjust the nx, ny coordinates slightly based on EDGE_PAD

    -- first we find out if we are blocked in the X or Y direction
    local nx, ny = x, y -- reset since we shouldn't move
    local isBlockedX, isBlockedY = false, false
    if isTileBlocked then
        for i = 1, #blockingSquares do
            local block = blockingSquares[i]
            if block.deltaX ~= 0 then
                isBlockedX = true
            end
            if block.deltaY ~= 0 then
                isBlockedY = true
            end
        end
    end

    -- handle vehicle collision sliding if we hit a vehicle
    if isVehicleBlocked then
        ---@cast hitX number
        ---@cast hitY number
        local slideX, slideY = getVehicleSlideDelta(isGalloping, x, y, vx, vy, hitX, hitY)

        nx, ny = x + slideX, y + slideY
    end

    ---@TODO
    -- the handling with the tile blocked is not perfect at all
    -- players can technically abuse horses to clip through walls
    -- so this part will need to be improved in the future

    -- adjust the positions back slightly to avoid clipping into the wall
    local dirX = signf(distance:getX())
    local dirY = signf(distance:getY())
    nx = isBlockedX and (nx - dirX * EDGE_PAD) or nx
    ny = isBlockedY and (ny - dirY * EDGE_PAD) or ny

    -- final position update with collision adjustments (hugging walls)
    updatePosition(horse, nx, ny)
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

-- Set animation variables for mounted movement states
local function setMountedMovementVariables(pair, isMoving, isGalloping)
    MountedAnimationState.setMovementVariables(pair.rider, pair.mount, isMoving, isGalloping)
end

-- Position the rider at the same location as the horse (they move together)
local function setRiderMountedPosition(rider, x, y, z)
    rider:setForceX(x)  -- Force position to keep rider exactly on horse
    rider:setForceY(y)
    rider:setZ(z)
end

---@param pair MountPair
---@param args RidingStateArguments
-- Apply a complete movement state snapshot (used for synchronization and snapping)
function RidingMovement.applyState(pair, args)
    if not hasValidStateTransform(args) then
        return
    end

    local rider = pair.rider
    local mount = pair.mount
    local dir = IsoDirections.fromIndex(math.floor(args.dir))

    -- Set position and clear pathfinding behavior
    mount:setX(args.x)
    mount:setY(args.y)
    mount:setZ(args.z)
    mount:getPathFindBehavior2():reset()
    mount:setPath2(nil)
    mount:setMoving(args.speed > 0)
    mount:setVariable("bPathfind", false)
    setRiderMountedPosition(rider, args.x, args.y, args.z)

    -- Clear cached body angle to force immediate resync rather than smooth rotation
    -- (important during position snaps to prevent animation lag)
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
-- Update slowdown effect from nearby zombies
-- Applies penalties for zombie proximity and knockdowns
function RidingMovement:updateSlowdown(deltaTime)
    -- Decay slowdown counter over time
    self.slowdownCounter = math.max(self.slowdownCounter - deltaTime, 0)

    local square = self.pair.mount:getSquare()
    if not square then
        return
    end

    -- Check all moving objects in the current square (mainly zombies)
    local movingObjects = square:getLuaMovingObjectList() ---@as IsoMovingObject[]
    for i = 1, #movingObjects do
        local zombie = movingObjects[i]
        if instanceof(zombie, "IsoZombie") then
            ---@cast zombie IsoZombie
            -- Downed zombies slow the horse less than standing ones
            if zombie:isKnockedDown() or zombie:isCrawling() then
                self.slowdownCounter = self.slowdownCounter + SLOWDOWN_ZOMBIE_GROUND_INCREASE * deltaTime
            else
                -- At high speed, the horse can knock down zombies
                if self.speed >= KNOCKDOWN_MIN_SPEED then
                    self.slowdownCounter = self.slowdownCounter + SLOWDOWN_ZOMBIE_KNOCKDOWN_INCREASE
                    if self.effects.authoritative then
                        -- Knockdown is more effective if zombie faces same direction
                        local facingSameDir = math.abs(zombie:getDirectionAngle() - directionToDegrees(self.direction)) <= 180
                        zombie:knockDown(facingSameDir)
                    end
                else
                    -- At lower speeds, just get slowed down by proximity
                    self.slowdownCounter = self.slowdownCounter + SLOWDOWN_ZOMBIE_NEARBY_INCREASE * deltaTime
                end
            end
        end
    end

    self.slowdownCounter = math.min(self.slowdownCounter, SLOWDOWN_MAX)
end

---@param input RidingMovementInput
---@param deltaTime number
-- Update horse rotation based on input and target direction
function RidingMovement:turn(input, deltaTime)
    local currentDirection = self.direction

    -- Calculate target direction from input (rotate left for isometric view)
    local targetDirection = currentDirection
    if input.movement.x ~= 0 or input.movement.y ~= 0 then
        targetDirection = IsoDirections.fromAngle(input.movement.x, input.movement.y):RotLeft()
    end

    -- Accumulate turn steps based on elapsed time
    self.turnAcceleration = self.turnAcceleration + deltaTime * TURN_STEPS_PER_SEC
    local turnDistance = currentDirection:compareTo(targetDirection)
    local absoluteTurnDistance = math.abs(turnDistance)
    -- Take shorter rotation path (if > 4 steps away, go the other direction)
    if absoluteTurnDistance > 4 then
        turnDistance = (-turnDistance + 4) % 8
    end

    -- Apply accumulated turns (up to the distance needed)
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
-- Update tree fall mechanics (falling off horse when galloping through trees)
function RidingMovement:updateTreeFall(isGalloping, deltaTime)
    local rider = self.pair.rider
    local mount = self.pair.mount
    local timeInTrees = self.timeInTrees

    if isGalloping then
        -- Accumulate time spent in trees while galloping
        if rider:isInTreesNoBush() or mount:isInTreesNoBush() then
            self.timeInTrees = timeInTrees + deltaTime
            -- Check for fall periodically
            if self.lastCheck > 0.5 then
                self:rollForTreeFall()
                self.lastCheck = 0.0
            else
                self.lastCheck = self.lastCheck + deltaTime
            end
        end
    elseif self.timeInTrees > 0 then
        -- Decay time in trees when not galloping (4x faster decay)
        timeInTrees = math.max(0, timeInTrees - deltaTime * 4)
        timeInTrees = math.min(timeInTrees, 10)  -- Cap at 10 seconds
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

-- Start a jump
-- Locks rider controls during jump animation
function RidingMovement:startJump()
    local character = self.pair.rider
    self.pair:setAnimationVariable(AnimationVariable.JUMP, true)
    -- Prevent rider input during jump
    character:setIgnoreMovement(true)
    character:setIgnoreInputsForDirection(true)
    character:setIgnoreAimingInput(true)
    character:setIsAiming(false)

    self.doTurn = false  -- Don't turn during jump
    self.jumpTime = JUMP_SECONDS
    self.jumpCooldown = JUMP_COOLDOWN_SECONDS
end

-- Begin jump cooldown (without playing jump animation)
-- Used by HorseJump timed action to share cooldown with regular jumps
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
-- Make the horse follow the floor height (stairs, ramps, etc.)
-- Keeps the horse properly aligned with terrain elevation
function RidingMovement:followVertical(mount, deltaTime)
    local x = mount:getX()
    local y = mount:getY()
    local mz = mount:getZ()

    -- Find the floor beneath the horse
    local best = findFloorSquare(x, y, mz)
    local bestZ = best and floorHeight(best, x, y) or nil

    -- Only consider moving to a higher floor if horse is in upper half of current level
    -- (prevents teleporting up from ground level)
    if (mz - math.floor(mz)) >= 0.5 then
        local above = getSq(x, y, math.floor(mz) + 1)
        if above and (above:has(IsoFlagType.solidfloor) or above:HasStairs() or above:hasSlopedSurface()) then
            local zAbove = floorHeight(above, x, y)
            -- Use higher floor if it's closer to the horse
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

    -- Snap to floor if close enough (within max step distance)
    if math.abs(bestZ - mz) < VERTICAL_FOLLOW_MAX_STEP then
        mount:setZ(bestZ)
        mount:setLastZ(bestZ)
    end

    -- Update mount's current square
    mount:setCurrent(best)
    mount:setMovingSquareNow()

    -- Refresh ramp grace period if on slope
    if squareIsRamp(best) then
        self.rampGrace = RAMP_FALL_GRACE_SECONDS
    else
        self.rampGrace = math.max(0, self.rampGrace - deltaTime)
    end

    self.lastFloorSquare = best
end


-- Check if mount is on stairs or sloped surface
-- Used to avoid false fall detection while on ramps
---@param mount IsoAnimal
---@return boolean
---@nodiscard
function RidingMovement:onStairsOrSlope(mount)
    -- Grace period still active from recent ramp detection
    if self.rampGrace > 0 then
        return true
    end

    -- Check current floor square
    local square = self.lastFloorSquare or findFloorSquare(mount:getX(), mount:getY(), mount:getZ())
    if square ~= nil and squareIsRamp(square) then
        return true
    end

    -- Check square below
    local below = getCell():getGridSquare(math.floor(mount:getX()), math.floor(mount:getY()), math.floor(mount:getZ()) - 1)
    return below ~= nil and squareIsRamp(below)
end

-- Check if mount is actually touching the ground (within tolerance)
-- More reliable than isbFalling which can trigger false positives
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
        SPEED_VECTOR2:setLengthAndDirection(moveAngle, self.speed * deltaTime)
        moveWithCollision(rider, mount, SPEED_VECTOR2, isGalloping, isJumping, self.effects)

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
-- Constructor: Create a new RidingMovement controller
---@param pair MountPair
---@param effects RidingMovementEffects
---@return RidingMovement
---@nodiscard
function RidingMovement.new(pair, effects)
    return setmetatable(
        {
            pair = pair,
            effects = effects,
            -- Turning
            turnAcceleration = 0,  -- Accumulated turn progress
            lastTurnWasRight = false,  -- Direction of last turn
            -- Vegetation slowdown
            vegetationLingerTime = 0.0,  -- Time remaining to apply vegetation penalty
            vegetationLingerStartMult = 1.0,  -- Starting multiplier for vegetation linger easing
            -- Tree fall
            timeInTrees = 0.0,  -- Accumulates while galloping in trees
            lastCheck = 0.0,  -- Time since last tree fall check
            -- Zombie slowdown
            slowdownCounter = 0.0,  -- Slowdown accumulation from zombies
            -- Movement
            speed = 0.0,  -- Current movement speed
            doTurn = true,  -- Whether turning is allowed
            forcedInput = nil,  -- Forced input during jump
            -- Jumping
            jumpTime = 0,  -- Time remaining in jump animation
            jumpCooldown = 0,  -- Time remaining before next jump allowed
            -- State sync
            lastAuthoritativeSeq = -1,  -- Last authoritative state sequence number
            -- Direction
            direction = pair.rider:getDir(),  -- Current horse direction
            turnAnimSign = 0,  -- Turn animation direction (-1, 0, 1)
            turnAnimTime = 0.0,  -- Time to continue showing turn animation
            -- Server state tracking
            lastAppliedX = nil--[[@as number?]],
            lastAppliedY = nil--[[@as number?]],
            lastAppliedZ = nil--[[@as number?]],
            lastAppliedDir = nil--[[@as integer?]],
            -- Gallop transition
            wasGalloping = false,  -- Was galloping in previous frame
            idleToRunTimer = 0.0,  -- Time to play idle-to-run transition animation
            -- Floor tracking
            lastFloorSquare = nil--[[@as IsoGridSquare?]],  -- Last detected floor square
            rampGrace = 0.0,  -- Grace period for ramp fall detection
        },
        RidingMovement
    )
end

return RidingMovement
