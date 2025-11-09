local Stamina = require("HorseMod/Stamina")


function GetSpeeds()
    local options = PZAPI.ModOptions:getOptions("HorseMod")
    if not options then return 1.0 end
    -- TODO: replace mod options with sandbox options
    local walk = options:getOption("HorseWalkSpeed"):getValue()
    local gallop = options:getOption("HorseGallopSpeed"):getValue()
    if walk and gallop then return walk, gallop end
    return 1.0
end

local function getBaseGeneSpeed(horse)
    local md = horse:getModData()
    md.HM_Ride = md.HM_Ride or {}
    if type(md.HM_Ride.geneBase) ~= "number" then
        local v = tonumber(horse:getVariableString("geneSpeed")) or 1.0
        md.HM_Ride.geneBase = v
    end
    return md.HM_Ride.geneBase
end

local function smoothstep(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    return t*t*(3 - 2*t)
end

local function lerp(a, b, t) return a + (b - a) * t end

local function getSq(x,y,z) return getCell():getGridSquare(math.floor(x), math.floor(y), z) end

local function hedgeMultFromTree(treeMult)
    return 1.0 - (1.0 - treeMult) * 0.5
end


local function detectVegetation(player)
    local square   = player and player:getCurrentSquare() or nil
    local tree     = square and square:getTree() or nil
    local props    = square and square:getProperties() or nil
    local movement = props and props:Val("Movement") or nil

    local isTree  = false
    local isHedge = false
    local isBush  = false

    if tree then
        isTree = (tree:getSize() > 2)
        isBush = not isTree
    elseif movement and (movement == "HedgeLow" or movement == "HedgeHigh") then
        isHedge = true
    elseif square and square:hasBush() then
        isBush = true
    end

    return isTree, isHedge, isBush
end

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

local function approach(current, target, rate, dt)
    local delta = target - current
    if delta > 0 then
        local step = math.min(delta, rate * dt);
        return current + step
    else
        local step = math.max(delta, -rate * dt); return current + step
    end
end


---@param first IsoDirections
---@param second IsoDirections
local function dirDist4(first, second)
    local distance = first:compareTo(second)

    if distance < 0 then
        distance = distance + 4
    end

    return distance
end


local WALK_SPEED = 0.05      -- tiles/sec
local TROT_MULT  = 1.1
local RUN_SPEED  = 4.5       -- tiles/sec

local TREES_GENE_MULT_WALK = 0.40   -- 65% of base when walking/trotting in trees
local TREES_GENE_MULT_RUN  = 0.25   -- 55% of base when galloping in trees
local TREES_LINGER_SECONDS = 1.0   -- keep slowdown for 1s after leaving trees

local ACCEL_UP   = 12.0
local DECEL_DOWN = 36.0

local TURN_STEPS_PER_SEC = 14


local PLAYER_SYNC_TUNER = 0.96



---@namespace HorseMod


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
---@field vegLingerT number
---
---@field vegLingerStartMult number
---
---@field prevInVeg boolean
---
---@field currentSpeed number
local MountController = {}
MountController.__index = MountController


---@class MountController.Input
---@field movement {x: number, y: number}
---@field run boolean


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
        -- we don't want to change turning direction druing a 180
        shouldTurnRight = turnDistance > 0
    end

    if turns >= 1 then
        if shouldTurnRight then
            currentDirection = currentDirection:RotRight(
                turns
            )
        else
            currentDirection = currentDirection:RotLeft(
                turns
            )
        end
        self.turnAcceleration = self.turnAcceleration % 1
    end

    self.lastTurnWasRight = shouldTurnRight

    -- lock both to the same stepped direction
    self.mount.pair:setDirection(currentDirection)
end


---@param input MountController.Input
---@param deltaTime number
function MountController:updateStamina(input, deltaTime)
    local staminaChange = 0.0

    -- Drain / regen
    if input.movement.x ~= 0 or input.movement.y ~= 0 then
        if input.run then
            staminaChange = -Stamina.DRAIN_RUN
        elseif self.mount.pair.mount:getVariableBoolean("HorseTrot") == true then
            staminaChange = Stamina.REGEN_TROT
        else
            staminaChange = Stamina.REGEN_WALK
        end
    else
        staminaChange = Stamina.REGEN_IDLE
    end

    Stamina.modify(self.mount.pair.mount, staminaChange * deltaTime, true)
end


---@param input MountController.Input
function MountController:update(input)
    -- FIXME: this sometimes fails when dismounting
    assert(self.mount.pair.rider:getVariableString("RidingHorse") == "true")

    self.mount.pair.rider:setSneaking(true)

    -- TODO i'm doubtful this is needed?
    self.mount.pair.mount:getPathFindBehavior2():reset()
    self.mount.pair.mount:getBehavior():setBlockMovement(true)

    local deltaTime = GameTime.getInstance():getTimeDelta()
    local moving = (input.movement.x ~= 0 or input.movement.y ~= 0)

    -- Prevent running at zero stamina
    if not Stamina.canRun(self.mount.pair.mount) then
        input.run = false
    end

    self:updateStamina(input, deltaTime)
    self:turn(input, deltaTime)

    local walkMul, gallopMul = GetSpeeds()

    local baseGene = getBaseGeneSpeed(self.mount.pair.mount) or 1.0
    local isTree, isHedge, isBush = detectVegetation(self.mount.pair.rider)

    local treeMultNow  = (input.run and TREES_GENE_MULT_RUN or TREES_GENE_MULT_WALK)
    local hedgeMultNow = hedgeMultFromTree(treeMultNow)

    local vegMultNow
    if isTree then
        vegMultNow = treeMultNow
    elseif isHedge then
        vegMultNow = hedgeMultNow
    else
        vegMultNow = 1.0
    end

    local inVeg = (vegMultNow < 1.0)

    if inVeg then
        self.vegLingerT = 0
        self.vegLingerStartMult = vegMultNow
    else
        if self.prevInVeg == true then
            self.vegLingerT = TREES_LINGER_SECONDS
            self.vegLingerStartMult = self.vegLingerStartMult or vegMultNow
        end
    end
    self.prevInVeg = inVeg

    local mult
    if inVeg then
        mult = vegMultNow
    else
        local tRemain = self.vegLingerT
        if tRemain > 0 then
            local p = 1.0 - (tRemain / TREES_LINGER_SECONDS)
            local eased = smoothstep(p)
            local start = self.vegLingerStartMult
            mult = lerp(start, 1.0, eased)
            self.vegLingerT = math.max(0, tRemain - deltaTime)
        else
            mult = 1.0
        end
    end

    local effGene = baseGene * mult

    local curGeneStr = self.mount.pair.mount:getVariableString("geneSpeed")
    local effStr = string.format("%.3f", effGene)
    if curGeneStr ~= effStr then
        self.mount.pair.mount:setVariable("geneSpeed", effStr)
        self.mount.pair.rider:setVariable("geneSpeed", effStr)
    end

    if input.run then
        local f = Stamina.runSpeedFactor(self.mount.pair.mount)
        gallopMul = gallopMul * f
    end

    self.mount.pair.mount:setVariable("HorseWalkSpeed", walkMul)
    self.mount.pair.mount:setVariable("HorseTrotSpeed",  walkMul * TROT_MULT)
    self.mount.pair.mount:setVariable("HorseRunSpeed",  gallopMul)

    self.mount.pair.rider:setVariable("HorseWalkSpeed", walkMul * PLAYER_SYNC_TUNER)
    self.mount.pair.rider:setVariable("HorseTrotSpeed",  walkMul * TROT_MULT * PLAYER_SYNC_TUNER)
    self.mount.pair.rider:setVariable("HorseRunSpeed",  gallopMul * PLAYER_SYNC_TUNER)

    -- speed/locomotion
    local target  = (moving and (input.run and RUN_SPEED * gallopMul or WALK_SPEED * walkMul)) or 0.0
    local rate    = (target > self.currentSpeed) and ACCEL_UP or DECEL_DOWN
    self.currentSpeed = approach(self.currentSpeed, target, rate, deltaTime)
    if self.currentSpeed < 0.0001 then self.currentSpeed = 0 end
    self.currentSpeed = self.currentSpeed

    if moving and self.currentSpeed > 0 then
        local currentDirection = self.mount.pair.mount:getDir()
        local vx, vy = currentDirection:dx() * self.currentSpeed, currentDirection:dy() * self.currentSpeed
        moveWithCollision(self.mount.pair.mount, vx, vy, deltaTime)

        self.mount.pair.mount:setVariable("bPathfind", true)
        self.mount.pair.mount:setVariable("animalWalking", not input.run)
        self.mount.pair:setAnimationVariable("HorseGallop", input.run)
    else
        self.mount.pair.mount:setVariable("bPathfind", false)
        self.mount.pair:setAnimationVariable("HorseGallop", false)
        self.mount.pair.mount:setVariable("animalWalking", false)
    end

    local mirrorVars =  { "HorseGalloping","isTurningLeft","isTurningRight" }
    for i = 1, #mirrorVars do
        local k = mirrorVars[i]
        local v = self.mount.pair.mount:getVariableBoolean(k)
        if self.mount.pair.rider:getVariableBoolean(k) ~= v then
            self.mount.pair.rider:setVariable(k, v)
        end
    end

    self.mount.pair.rider:setX(self.mount.pair.mount:getX())
    self.mount.pair.rider:setY(self.mount.pair.mount:getY())
    self.mount.pair.rider:setZ(self.mount.pair.mount:getZ())
    self.mount.pair.rider:setVariable("mounted", true)
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
            vegLingerT = 0.0,
            vegLingerStartMult = 1.0,
            prevInVeg = false
        },
        MountController
    )
end


return MountController