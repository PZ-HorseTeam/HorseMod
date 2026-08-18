---@namespace HorseMod

local AnimationVariable = require("HorseMod/definitions/AnimationVariable")

local MountedAnimationState = {}

local ANIMATION_SPEED_WALK = 1.5
local TROT_MULT = 1.1
local PLAYER_SYNC_TUNER = 1

---@param horse IsoAnimal
---@return number
---@nodiscard
local function getGeneticSpeed(horse)
    return horse:getUsedGene("speed"):getCurrentValue()
end

---@param rider IsoPlayer
---@param horse IsoAnimal
---@param geneSpeed number?
function MountedAnimationState.setSpeedVariables(rider, horse, geneSpeed)
    local speedGene = geneSpeed
    if speedGene == nil then
        speedGene = getGeneticSpeed(horse)
    end

    local walkSpeed = SandboxVars.HorseMod.WalkSpeed ---@diagnostic disable-line
    local gallopSpeed = SandboxVars.HorseMod.GallopSpeed ---@diagnostic disable-line

    horse:setVariable(AnimationVariable.GENE_SPEED, speedGene)
    horse:setVariable(AnimationVariable.WALK_SPEED, walkSpeed * ANIMATION_SPEED_WALK)
    horse:setVariable(AnimationVariable.TROT_SPEED, walkSpeed * TROT_MULT)
    horse:setVariable(AnimationVariable.RUN_SPEED, gallopSpeed)

    rider:setVariable(AnimationVariable.GENE_SPEED, speedGene)
    rider:setVariable(AnimationVariable.WALK_SPEED, walkSpeed * PLAYER_SYNC_TUNER * ANIMATION_SPEED_WALK)
    rider:setVariable(AnimationVariable.TROT_SPEED, walkSpeed * TROT_MULT * PLAYER_SYNC_TUNER)
    rider:setVariable(AnimationVariable.RUN_SPEED, gallopSpeed * PLAYER_SYNC_TUNER)
end

---@param rider IsoPlayer
---@param horse IsoAnimal
---@param isMoving boolean
---@param isGalloping boolean
function MountedAnimationState.setMovementVariables(rider, horse, isMoving, isGalloping)
    local walking = isMoving and not isGalloping
    local running = isMoving and isGalloping

    horse:setVariable("animalWalking", walking)
    horse:setVariable("animalRunning", running)
    horse:setVariable("HorseGalloping", running)
    horse:setVariable("HorseMountedMoving", isMoving)
    horse:setVariable("walkstateRun", false)

    rider:setVariable("animalWalking", walking)
    rider:setVariable("animalRunning", running)
    rider:setVariable("HorseGalloping", running)
    rider:setVariable("HorseMountedMoving", isMoving)
    rider:setVariable("walkstateRun", false)
end

---@param rider IsoPlayer
---@param horse IsoAnimal
---@param turn integer
function MountedAnimationState.setTurnVariables(rider, horse, turn)
    local turningLeft = turn < 0
    local turningRight = turn > 0
    local turning = turningLeft or turningRight

    horse:setVariable("isTurningLeft", turningLeft)
    horse:setVariable("isTurningRight", turningRight)
    horse:setVariable("isTurning", turning)

    rider:setVariable("isTurningLeft", turningLeft)
    rider:setVariable("isTurningRight", turningRight)
    rider:setVariable("isTurning", turning)
end

---@param rider IsoPlayer
---@param hasReins boolean
function MountedAnimationState.setReinsVariable(rider, hasReins)
    rider:setVariable(AnimationVariable.HAS_REINS, hasReins)
end

return MountedAnimationState
