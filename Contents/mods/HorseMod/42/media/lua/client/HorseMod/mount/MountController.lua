---REQUIREMENTS
local Stamina = require("HorseMod/Stamina")
local AnimationVariable = require('HorseMod/definitions/AnimationVariable')
local Mounting = require("HorseMod/Mounting")
local HorseJump = require("HorseMod/TimedActions/HorseJump")
local rdm = newrandom()



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
---@param velocity Vector2
---@param delta number
---@param isGalloping boolean
---@param isJumping boolean
local function moveWithCollision(rider, horse, velocity, delta, isGalloping, isJumping)
    local z = horse:getZ()
    local x = horse:getX()
    local y = horse:getY()

    local velocityX = velocity:getX()
    local velocityY = velocity:getY()

    local maxVel = math.max(
        math.abs(velocityX),
        math.abs(velocityY)
    )
    if maxVel == 0 then return end

    -- collision uses fixed time steps to maintain precision
    --  i'm kind of sceptical that this does anything though, this is really high
    --  you'd have to be running below 15fps for this to come into play 
    local maxStepDist = 0.065

    local remaining = delta
    while remaining > 0 do
        local s = math.min(remaining, maxStepDist / maxVel)
        local dx = velocityX * s
        local dy = velocityY * s

        -- check if hitting a wall
        local rx, ry = collideStepAt(horse, z, x, y, dx, dy, isJumping)
        if rx == 0 and ry == 0 then
            if isGalloping then
                Mounting.dismountFallBack(rider, horse)
            end
            break
        end

        local nx = x + rx
        local ny = y + ry
        if squareCenterSolid(getSquare(nx, ny, z)) then
            break
        end

        x = nx
        y = ny
        remaining = remaining - s
    end

    -- Single commit per frame
    horse:setX(x)
    horse:setY(y)
end


---@param current number
---@param target number
---@param rate number
---@param deltaTime number
---@return number
local function approach(current, target, rate, deltaTime)
    local delta = target - current
    if delta > 0 then
        ---@type number
        local step = math.min(delta, rate * deltaTime)
        return current + step
    else
        local step = math.max(delta, -rate * deltaTime)
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


local WALK_SPEED = 0.05      -- tiles/sec
local TROT_MULT  = 1.1
local RUN_SPEED  = 4.5       -- tiles/sec

local TREES_GENE_MULT_WALK = 0.40   -- 65% of base when walking/trotting in trees
local TREES_GENE_MULT_RUN  = 0.25   -- 55% of base when galloping in trees
local TREES_LINGER_SECONDS = 1.0   -- keep slowdown for 1s after leaving trees

local ACCEL_UP   = 12.0
local DECEL_DOWN = 36.0

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
---Current movement speed in squares/s.
---@field targetSpeed number
---
---Used to calculate if the player should fall while in trees. Chance increases the longer they stay in trees.
---@field timeInTrees number
---
---Last time a tree fall check was made.
---@field lastCheck number
---
---Indicates whether the pair can turn this update.
---@field doTurn boolean
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
---@nodiscard
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


---@param input InputManager.Input
---@param deltaTime number
function MountController:updateSpeed(input, deltaTime)
    local walkMultiplier = getSpeed("walk")
    local gallopRawSpeed = getSpeed("gallop")
    local gallopMultiplier = gallopRawSpeed

    local pair = self.mount.pair
    local mount = pair.mount
    local rider = pair.rider

    -- vegetation slowdown is applied through gene speed?
    local geneSpeed = getGeneticSpeed(mount) * self:getVegetationEffect(input, deltaTime)

    -- TODO: is this check really necessary? does changing the value cause more overhead than reading it?
    local currentGeneSpeed = mount:getVariableFloat(AnimationVariable.GENE_SPEED, 0)
    if currentGeneSpeed ~= geneSpeed then
        pair:setAnimationVariable(AnimationVariable.GENE_SPEED, geneSpeed)
    end

    if input.run then
        local f = Stamina.runSpeedFactor(mount)
        if f < 0.35 then
            gallopMultiplier = 0.35
        else
            gallopMultiplier = gallopMultiplier * f
        end
    end

    mount:setVariable(AnimationVariable.WALK_SPEED, walkMultiplier)
    mount:setVariable(AnimationVariable.TROT_SPEED,  walkMultiplier * TROT_MULT)
    mount:setVariable(AnimationVariable.RUN_SPEED, gallopRawSpeed)

    rider:setVariable(AnimationVariable.WALK_SPEED, walkMultiplier * PLAYER_SYNC_TUNER)
    rider:setVariable(AnimationVariable.TROT_SPEED,  walkMultiplier * TROT_MULT * PLAYER_SYNC_TUNER)
    rider:setVariable(AnimationVariable.RUN_SPEED, gallopRawSpeed * PLAYER_SYNC_TUNER)

    -- speed/locomotion
    local moving = (input.movement.x ~= 0 or input.movement.y ~= 0)
    local target = (moving and (input.run and RUN_SPEED * gallopMultiplier or WALK_SPEED * walkMultiplier)) or 0.0
    local rate = (target > self.targetSpeed) and ACCEL_UP or DECEL_DOWN
    
    self.targetSpeed = approach(self.targetSpeed, target, rate, deltaTime)
    
    if self.targetSpeed < 0.0001 then
        self.targetSpeed = 0
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
    if self.targetSpeed <= 0 then
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
---@return number
function MountController:getCurrentSpeed()
    return self.mount.pair.mount:getMovementSpeed() / GameTime.getInstance():getTimeDelta()
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
    self:updateSpeed(input, deltaTime)

    if moving and self.targetSpeed > 0
        and not rider:getVariableBoolean(AnimationVariable.DISMOUNT_STARTED) then
        local currentDirection = mount:getDir()
        local velocity = currentDirection:ToVector():setLength(self.targetSpeed)
        moveWithCollision(rider, mount, velocity, deltaTime, isGalloping, isJumping)

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
            targetSpeed = 0.0,
            vegetationLingerTime = 0.0,
            vegetationLingerStartMult = 1.0,
            timeInTrees = 0.0,
            lastCheck = 0.0,
            doTurn = true,
        },
        MountController
    )
end


return MountController