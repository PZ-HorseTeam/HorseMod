---@namespace HorseMod

---@enum AnimationVariable
local AnimationVariable = {
    -- Movement states
    IS_HORSE = "isHorse",
    WALK = "HorseWalk",
    GALLOP = "HorseGallop",
    GALLOPING = "HorseGalloping",
    TROT = "HorseTrot",
    JUMP = "HorseJump",
    DYING = "HorseDying",
    FALL_BACK = "HorseFallBack",
    GALLOPING = "HorseGalloping",

    WALKING = "animalWalking",
    RUNNING = "animalRunning",
    WALKSTATE_RUN = "walkstateRun",

    IS_TURNING_LEFT = "isTurningLeft",
    IS_TURNING_RIGHT = "isTurningRight",
    IS_TURNING = "isTurning",

    IS_RUNNING = "animalWalking",
    IS_WALKING = "animalRunning",
    WALKSTATE_RUN = "walkstateRun",

    -- Activates mounted player animations while true.
    -- albion: this should be controlled by Mounts only, please check with me first if you think your code needs to set it
    RIDING_HORSE = "HorseRiding",
    MOUNTING_HORSE = "HorseMountingHorse",
    DISMOUNT_STARTED = "HorseDismountStarted",

    -- Prevents the player from cancelling the mount/dismount animation
    -- see ActionCancel.lua
    NO_CANCEL = "HorseNoCancel",

    -- getMovementSpeed() is 0 on server, so we use this flag instead
    MOUNTED_MOVING = "HorseMountedMoving",

    -- True for the first ticks of a fresh gallop so the IdleToGallop
    -- transition anim plays before settling into the gallop loop
    IDLE_TO_RUN = "IdleToRun",

    HAS_REINS = "HorseHasReins",

    -- Signed angular distance (degrees) from current visual facing to target facing.
    -- Positive = right turn, negative = left, 0 = no turn
    -- Replaces vanilla `targetTwist`
    MOUNTED_TWIST = "mountedTwist",

    EATING = "HorseEating",
    EATING_HAND = "HorseEatingHand",
    HURT = "HorseHurt",
    DEATH = "HorseDeath",

    KICK_LEFT = "HorseRiderKickLeft",
    KICK_RIGHT = "HorseRiderKickRight",
    IDLE_KICKING = "HorseRiderIdleKicking",
    MOVE_KICKING = "HorseRiderMoveKicking",

    WALK_SPEED = "HorseWalkSpeed",
    TROT_SPEED = "HorseTrotSpeed",
    RUN_SPEED = "HorseRunSpeed",

    -- Multiplier to the horse's speed from genetics
    GENE_SPEED = "HorseGeneSpeed",
    -- unused
    GENE_STRENGTH = "HorseGeneStrength",
    -- unused
    GENE_STAMINA = "HorseGeneStamina",
    -- unused
    GENE_CARRYWEIGHT = "HorseGeneCarryWeight",
}

return AnimationVariable