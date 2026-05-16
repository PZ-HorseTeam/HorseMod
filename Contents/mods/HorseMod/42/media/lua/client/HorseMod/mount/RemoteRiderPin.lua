---@namespace HorseMod

local AnimationVariable = require("HorseMod/definitions/AnimationVariable")
local MountedDirection = require("HorseMod/riding/MountedDirection")
local Mounts = require("HorseMod/Mounts")

local RemoteRiderPin = {}

local MAX_PIN_Z_DELTA = 2

---@param rider IsoPlayer
local function keepRemoteRiderLocked(rider)
    if not rider:getIgnoreMovement() then
        rider:setIgnoreMovement(true)
    end

    if not rider:isIgnoreInputsForDirection() then
        rider:setIgnoreInputsForDirection(true)
    end

    if not rider:isIgnoringAimingInput() then
        rider:setIgnoreAimingInput(true)
    end

    rider:setAllowRun(false)
    rider:setAllowSprint(false)
    rider:setSneaking(false)
    rider:setIgnoreAutoVault(true)
end

---@param rider IsoPlayer
---@param x number
---@param y number
---@param z number
---@param direction IsoDirections
function RemoteRiderPin.pinRiderToPosition(rider, x, y, z, direction)
    if rider:isLocalPlayer() then
        return
    end

    keepRemoteRiderLocked(rider)

    rider:setForceX(x)
    rider:setForceY(y)
    rider:setZ(z)
    rider:setVariable(AnimationVariable.RIDING_HORSE, true)
    rider:setDir(direction)
    rider:setForwardIsoDirection(direction)
end

---@param rider IsoPlayer
---@param animal IsoAnimal
function RemoteRiderPin.pinRiderToAnimal(rider, animal)
    if rider:isLocalPlayer() then
        return
    end

    local dz = rider:getZ() - animal:getZ()
    if math.abs(dz) > MAX_PIN_Z_DELTA then
        return
    end

    local direction = MountedDirection.toRiderDirection(animal:getDir())
    animal:setVariable(AnimationVariable.RIDING_HORSE, true)
    RemoteRiderPin.pinRiderToPosition(
        rider,
        animal:getX(),
        animal:getY(),
        animal:getZ(),
        direction
    )
end

function RemoteRiderPin.update()
    if isClient() then
        Mounts.forEachLoadedMount(RemoteRiderPin.pinRiderToAnimal)
    elseif isServer() then
        return
    else
        return
    end
end

Events.OnRenderTick.Add(RemoteRiderPin.update)

return RemoteRiderPin
