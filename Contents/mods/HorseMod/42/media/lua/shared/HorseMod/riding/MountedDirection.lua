---@namespace HorseMod

local commands = require("HorseMod/networking/commands")
local AnimationVariable = require("HorseMod/definitions/AnimationVariable")

local MountedDirection = {}
local TEMP_VECTOR2 = Vector2.new()

local IS_SINGLEPLAYER = not (isClient() or isServer())

-- Visual turn step (radians) at the 30 FPS baseline
local SP_VISUAL_TURN_RADIANS_PER_30FPS_TICK     = 0.077  -- ≈ 2.3 rad/s ≈ 132°/s
local MP_VISUAL_TURN_RADIANS_PER_30FPS_TICK     = 0.039  -- ≈ 1.5 rad/s ≈ 86°/s
local REMOTE_VISUAL_TURN_RADIANS_PER_30FPS_TICK = 0.082  -- ≈ 1.4 rad/s ≈ 80°/s

local VISUAL_TURN_RADIANS_PER_30FPS_TICK = IS_SINGLEPLAYER
    and SP_VISUAL_TURN_RADIANS_PER_30FPS_TICK
    or MP_VISUAL_TURN_RADIANS_PER_30FPS_TICK

-- Defensive cap for game speed multipliers (like all-players sleep in MP which has 200x game speed)
local MAX_VISUAL_TURN_STEP = math.pi / 4

local TWO_PI = math.pi * 2
-- Vanilla targetTwist > 0 means right turn so we use the same
local MOUNTED_TWIST_SIGN = 1

---@type table<integer, number>
local visualAngles = {}

---@param angle number
---@return number
---@nodiscard
local function wrapAnglePi(angle)
    while angle <= -math.pi do
        angle = angle + TWO_PI
    end

    while angle > math.pi do
        angle = angle - TWO_PI
    end

    return angle
end

---@param current number
---@param target number
---@param maxStep number
---@return number
---@nodiscard
local function approachAngle(current, target, maxStep)
    local delta = wrapAnglePi(target - current)
    if math.abs(delta) <= maxStep then
        return target
    end

    if delta > 0 then
        return current + maxStep
    end

    return current - maxStep
end

---@param direction IsoDirections
---@return number
---@nodiscard
local function directionToAngle(direction)
    return Vector2.getDirection(direction:dx(), direction:dy())
end

---@param remoteVisual boolean?
---@return number
---@nodiscard
local function getVisualTurnStep(remoteVisual)
    local perTick30 = VISUAL_TURN_RADIANS_PER_30FPS_TICK
    if remoteVisual == true then
        perTick30 = REMOTE_VISUAL_TURN_RADIANS_PER_30FPS_TICK
    end

    local step = perTick30 * GameTime.getInstance():getThirtyFPSMultiplier()
    if step > MAX_VISUAL_TURN_STEP then
        step = MAX_VISUAL_TURN_STEP
    end
    return step
end

---@param animal IsoAnimal
---@param direction IsoDirections
---@param _deltaTime number Unused; Param kept so public set/setPair callers don't need to change.
---@param remoteVisual boolean?
---@param inputTarget IsoDirections? Rider's intent direction; if provided, mountedTwist is measured against it instead of `direction`
---@return number mountedTwist Signed degrees of angular distance from current visual facing to the rider's intent; matches `targetTwist`
local function setVisualDirection(animal, direction, _deltaTime, remoteVisual, inputTarget)
    local animalId = commands.getAnimalId(animal)
    local targetAngle = directionToAngle(direction)
    local currentAngle = visualAngles[animalId]

    if currentAngle == nil then
        currentAngle = animal:getAnimAngleRadians()
    end

    local visualAngle = approachAngle(currentAngle, targetAngle, getVisualTurnStep(remoteVisual))
    visualAngles[animalId] = visualAngle
    TEMP_VECTOR2:setLengthAndDirection(visualAngle, 1.0)
    animal:setTargetAndCurrentDirection(TEMP_VECTOR2:getX(), TEMP_VECTOR2:getY())

    local twistReference = inputTarget and directionToAngle(inputTarget) or targetAngle
    return math.deg(wrapAnglePi(twistReference - visualAngle)) * MOUNTED_TWIST_SIGN
end

---@param direction IsoDirections
---@return IsoDirections
---@nodiscard
function MountedDirection.toHorseDirection(direction)
    return direction
end

---@param direction IsoDirections
---@return IsoDirections
---@nodiscard
function MountedDirection.toRiderDirection(direction)
    return direction
end

---@param rider IsoPlayer
---@param animal IsoAnimal
---@param direction IsoDirections Logical mounted travel direction.
---@param deltaTime number?
---@param remoteVisual boolean?
---@param inputTarget IsoDirections? Rider's intent direction (the heading they're steering toward).
function MountedDirection.set(rider, animal, direction, deltaTime, remoteVisual, inputTarget)
    local horseDirection = MountedDirection.toHorseDirection(direction)
    local horseInputTarget = inputTarget and MountedDirection.toHorseDirection(inputTarget) or nil
    animal:setDir(horseDirection)
    local mountedTwist = 0
    if deltaTime then
        mountedTwist = setVisualDirection(animal, horseDirection, deltaTime, remoteVisual, horseInputTarget)
        animal:setDir(horseDirection)
    else
        visualAngles[commands.getAnimalId(animal)] = nil
        TEMP_VECTOR2:setLengthAndDirection(directionToAngle(horseDirection), 1.0)
        animal:setTargetAndCurrentDirection(TEMP_VECTOR2:getX(), TEMP_VECTOR2:getY())
    end
    rider:setDir(direction)
    -- Mirror the horse's smoothed visual angle to the rider, keeping them in sync
    rider:setTargetAndCurrentDirection(TEMP_VECTOR2:getX(), TEMP_VECTOR2:getY())
    rider:setVariable(AnimationVariable.MOUNTED_TWIST, mountedTwist)
    animal:setVariable(AnimationVariable.MOUNTED_TWIST, mountedTwist)
end

---@param pair MountPair
---@param direction IsoDirections Logical mounted travel direction.
---@param deltaTime number?
---@param remoteVisual boolean?
---@param inputTarget IsoDirections? Rider's intent direction (the heading they're steering toward).
function MountedDirection.setPair(pair, direction, deltaTime, remoteVisual, inputTarget)
    MountedDirection.set(pair.rider, pair.mount, direction, deltaTime, remoteVisual, inputTarget)
end

---@param animal IsoAnimal
---@param fallbackDirection IsoDirections? Used on the first tick before visualAngle is seeded.
---@return number radians
function MountedDirection.getMovementAngle(animal, fallbackDirection)
    local angle = visualAngles[commands.getAnimalId(animal)]
    if angle ~= nil then
        return angle
    end
    if fallbackDirection ~= nil then
        return directionToAngle(fallbackDirection)
    end
    return animal:getAnimAngleRadians() or 0
end

---@param animal IsoAnimal
function MountedDirection.clear(animal)
    if not animal then
        return
    end
    visualAngles[commands.getAnimalId(animal)] = nil
    animal:setVariable(AnimationVariable.MOUNTED_TWIST, 0)
end

return MountedDirection
