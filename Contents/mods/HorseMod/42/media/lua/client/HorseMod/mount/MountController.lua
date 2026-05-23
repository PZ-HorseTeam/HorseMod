local RidingMovement = require("HorseMod/riding/RidingMovement")
local Mounting = require("HorseMod/Mounting")

---@namespace HorseMod

---@class MountController
---@field mount Mount
---@field movement RidingMovement
---@field queuedJump boolean
local MountController = {}
MountController.__index = MountController

local AUTHORITATIVE_SNAP_DISTANCE_SQ = 2.25
local LOCAL_RECOVERY_DISTANCE_SQ = 100

---@return RidingMovementEffects
---@nodiscard
local function createEffects()
    local onGallopBlocked = function(rider, horse)
        Mounting.dismountFallBack(rider, horse)
    end
    local onTreeFall = function(rider, horse)
        Mounting.dismountFallBack(rider, horse)
    end
    local onFallDetected = function(rider, horse)
        Mounting.dismountFall(rider, horse)
    end

    if isClient() then
        return {
            authoritative = false,
            onGallopBlocked = onGallopBlocked,
            onTreeFall = onTreeFall,
            onFallDetected = onFallDetected,
        }
    elseif isServer() then
        return {
            authoritative = true,
        }
    else
        return {
            authoritative = true,
            onGallopBlocked = onGallopBlocked,
            onTreeFall = onTreeFall,
            onFallDetected = onFallDetected,
        }
    end
end

---@return "idle"|"walking"|"trot"|"gallop"
---@nodiscard
function MountController:getMovementState()
    return self.movement:getMovementState()
end

function MountController:toggleTrot()
    self.movement:toggleTrot()
end

---@return number
---@nodiscard
function MountController:getCurrentSpeed()
    return self.movement:getCurrentSpeed()
end

---@return IsoDirections
---@nodiscard
function MountController:getDirection()
    return self.movement:getDirection()
end

---@return boolean
---@nodiscard
function MountController:canJump()
    return self.movement:canJump()
end

function MountController:jump()
    -- When the jump key was spammed, repeated HorseJump:start calls were
    -- leaving the horse frozen mid animation
    self.queuedJump = true
end

---@param input RidingMovementInput
function MountController:update(input)
    if self.queuedJump then
        input.jump = true
        self.queuedJump = false
    end

    self.movement:update(input, GameTime.getInstance():getTimeDelta())
end

---@param args RidingStateArguments
function MountController:applyAuthoritativeState(args)
    self.movement:applyAuthoritativeState(args, AUTHORITATIVE_SNAP_DISTANCE_SQ)
end

---@param args RidingStateArguments
function MountController:applyRecoveryState(args)
    self.movement:applyRecoveryState(args, LOCAL_RECOVERY_DISTANCE_SQ)
end

---@param mount Mount
---@return MountController
---@nodiscard
function MountController.new(mount)
    return setmetatable(
        {
            mount = mount,
            movement = RidingMovement.new(mount.pair, createEffects()),
            queuedJump = false,
        },
        MountController
    )
end

return MountController
