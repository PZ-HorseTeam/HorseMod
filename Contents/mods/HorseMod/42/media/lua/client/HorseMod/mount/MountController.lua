local Stamina = require("HorseMod/Stamina")
local HorseUtils = require("HorseMod/Utils")
local AttachmentData = require("HorseMod/attachments/AttachmentData")
local Attachments = require("HorseMod/attachments/Attachments")
local AnimationVariables = require("HorseMod/AnimationVariables")


---@param state "walk"|"gallop"
---@return number
---@nodiscard
local function getSpeed(state)
    if state == "walk" then
        return SandboxVars.HorseMod.WalkSpeed
    else
        return SandboxVars.HorseMod.GallopSpeed
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
        if properties:get("Solid") or properties:get("SolidTrans") then
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
---@return boolean
---@nodiscard
local function blockedBetween(fromSq, toSq, horse)
    if fromSq == toSq then
        return false
    end

    -- FENCE
    local hop = edgeHoppableBetween(fromSq, toSq)
    if hop and hop:isHoppable() then
        if horse and horse:getVariableBoolean(AnimationVariables.JUMP) then
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
---@return boolean
---@nodiscard
local function canCross(fromX, fromY, toX, toY, z, horse)
    local from = getSquare(fromX, fromY, z)
    local to = getSquare(toX, toY, z)

    if not from or not to then
        return false
    end

    return not blockedBetween(from, to, horse) and not squareCenterSolid(to)
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
---@return number
---@return number
---@nodiscard
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

--- Do all substeps in locals; write back ONCE.
---@param horse IsoAnimal
---@param velocity Vector2
---@param delta number
local function moveWithCollision(horse, velocity, delta)
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

        local rx, ry = collideStepAt(horse, z, x, y, dx, dy)
        if rx == 0 and ry == 0 then
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
---@field currentSpeed number
local MountController = {}
MountController.__index = MountController


---@class MountController.Input
---@field movement {x: number, y: number}
---@field run boolean
---@field trot boolean


---@param input MountController.Input
---@param deltaTime number
function MountController:turn(input, deltaTime)
    local currentDirection = self.mount.pair.mount:getDir()

    local targetDirection
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


---@param input MountController.Input
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


---@param input MountController.Input
---@param deltaTime number
function MountController:updateSpeed(input, deltaTime)
    local walkMultiplier = getSpeed("walk")
    local gallopRawSpeed = getSpeed("gallop")
    local gallopMultiplier = gallopRawSpeed

    -- vegetation slowdown is applied through gene speed?
    local geneSpeed = getGeneticSpeed(self.mount.pair.mount) * self:getVegetationEffect(input, deltaTime)

    -- TODO: is this check really necessary? does changing the value cause more overhead than reading it?
    local currentGeneSpeed = self.mount.pair.mount:getVariableFloat(AnimationVariables.GENE_SPEED, 0)
    if currentGeneSpeed ~= geneSpeed then
        self.mount.pair:setAnimationVariable(AnimationVariables.GENE_SPEED, geneSpeed)
    end

    if input.run then
        local f = Stamina.runSpeedFactor(self.mount.pair.mount)
        if f < 0.35 then
            gallopMultiplier = 0.35
        else
            gallopMultiplier = gallopMultiplier * f
        end
    end

    self.mount.pair.mount:setVariable(AnimationVariables.WALK_SPEED, walkMultiplier)
    self.mount.pair.mount:setVariable(AnimationVariables.TROT_SPEED,  walkMultiplier * TROT_MULT)
    self.mount.pair.mount:setVariable(AnimationVariables.RUN_SPEED, gallopRawSpeed)

    self.mount.pair.rider:setVariable(AnimationVariables.WALK_SPEED, walkMultiplier * PLAYER_SYNC_TUNER)
    self.mount.pair.rider:setVariable(AnimationVariables.TROT_SPEED,  walkMultiplier * TROT_MULT * PLAYER_SYNC_TUNER)
    self.mount.pair.rider:setVariable(AnimationVariables.RUN_SPEED, gallopRawSpeed * PLAYER_SYNC_TUNER)

    -- speed/locomotion
    local moving = (input.movement.x ~= 0 or input.movement.y ~= 0)
    local target = (moving and (input.run and RUN_SPEED * gallopMultiplier or WALK_SPEED * walkMultiplier)) or 0.0
    local rate = (target > self.currentSpeed) and ACCEL_UP or DECEL_DOWN

    self.currentSpeed = approach(self.currentSpeed, target, rate, deltaTime)
    if self.currentSpeed < 0.0001 then
        self.currentSpeed = 0
    end
end

---@param mount IsoAnimal
---@param reinsItem InventoryItem
---@param state string
function MountController:setReinsState(mount, reinsItem, state)
    -- retrieve the model of reins model
    local fullType = reinsItem:getFullType()
    local attachmentDef = Attachments.getAttachmentDefinition(fullType, "Reins")
    local model = attachmentDef.model
    assert(model ~= nil, "No rein model for item " .. tostring(fullType))

    -- retrieve the model associated to the current state
    local suffix = AttachmentData.REIN_STATES[state]
    assert(suffix ~= nil, "No suffix for specified state " .. tostring(state))

    local state_model = model..AttachmentData.REIN_STATES[state]

    -- apply state model
    reinsItem:setStaticModel(state_model)
    mount:resetEquippedHandsModels()
end

---@param input MountController.Input
---@return "idle"|"walking"|"trot"|"gallop"
function MountController:getMovementState(input)
    if (input.movement.x == 0 and input.movement.y == 0) or self.currentSpeed <= 0 then
        return "idle"
    elseif input.run then
        return "gallop"
    elseif input.trot then
        return "trot"
    else
        return "walking"
    end
end

---@param input MountController.Input
function MountController:updateReins(input)
    local mountPair = self.mount.pair
    local mount = mountPair.mount
    local reinsItem = Attachments.getAttachedItem(mount, "Reins")
    
    if reinsItem then
        local movementState = self:getMovementState(input)

        self:setReinsState(mount, reinsItem, movementState)

        ---@TODO these states should be defined when the rider mounts the horse
        mountPair.rider:setVariable(AnimationVariables.HAS_REINS, true)
    else
        mountPair.rider:setVariable(AnimationVariables.HAS_REINS, false)
    end
end


---@param input MountController.Input
function MountController:update(input)
    assert(self.mount.pair.rider:getVariableString(AnimationVariables.RIDING_HORSE) == "true")

    self.mount.pair.rider:setSneaking(true)
    self.mount.pair.rider:setIgnoreAutoVault(true)

    -- TODO i'm doubtful this is needed?
    self.mount.pair.mount:getPathFindBehavior2():reset()
    self.mount.pair.mount:getBehavior():setBlockMovement(true)

    local deltaTime = GameTime.getInstance():getTimeDelta()
    local moving = (input.movement.x ~= 0 or input.movement.y ~= 0)

    -- Prevent running at zero stamina
    if not Stamina.shouldRun(self.mount.pair.mount, input, moving) then
        input.run = false
    else
        input.run = true
    end

    self:turn(input, deltaTime)
    self:updateSpeed(input, deltaTime)
    self:updateReins(input)

    if moving and self.currentSpeed > 0 then
        local currentDirection = self.mount.pair.mount:getDir()
        local velocity = currentDirection:ToVector():setLength(self.currentSpeed)
        moveWithCollision(self.mount.pair.mount, velocity, deltaTime)

        self.mount.pair.mount:setVariable("bPathfind", true)
        self.mount.pair.mount:setVariable("animalWalking", not input.run)
        self.mount.pair:setAnimationVariable(AnimationVariables.GALLOP, input.run)
    else
        self.mount.pair.mount:setVariable("bPathfind", false)
        self.mount.pair:setAnimationVariable(AnimationVariables.GALLOP, false)
        self.mount.pair.mount:setVariable("animalWalking", false)
    end

    local mirrorVarsHorse =  { "HorseGalloping","isTurningLeft","isTurningRight" }
    for i = 1, #mirrorVarsHorse do
        local k = mirrorVarsHorse[i]
        local v = self.mount.pair.mount:getVariableBoolean(k)
        if self.mount.pair.rider:getVariableBoolean(k) ~= v then
            self.mount.pair.rider:setVariable(k, v)
        end
    end

    local mirrorVarsRider =  { "IdleToRun" }
    for i = 1, #mirrorVarsRider do
        local k = mirrorVarsRider[i]
        local v = self.mount.pair.rider:getVariableBoolean(k)
        if self.mount.pair.mount:getVariableBoolean(k) ~= v then
            self.mount.pair.mount:setVariable(k, v)
        end
    end

    self.mount.pair.rider:setX(self.mount.pair.mount:getX())
    self.mount.pair.rider:setY(self.mount.pair.mount:getY())
    self.mount.pair.rider:setZ(self.mount.pair.mount:getZ())
    UpdateHorseAudio(self.mount.pair.rider)
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
            currentSpeed = 0.0,
            vegetationLingerTime = 0.0,
            vegetationLingerStartMult = 1.0,
        },
        MountController
    )
end


return MountController