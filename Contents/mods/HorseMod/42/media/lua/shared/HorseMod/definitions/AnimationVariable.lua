---@namespace HorseMod

---@enum AnimationVariable
local AnimationVariable = {
    --- Must always be true on all horses for their animations to play properly.
    IS_HORSE = "isHorse",
    WALK = "HorseWalk",
    GALLOP = "HorseGallop",
    TROT = "HorseTrot",
    JUMP = "HorseJump",
    DYING = "HorseDying",
    FALL_BACK = "HorseFallBack",

    -- Activates mounted player animations while true
    RIDING_HORSE = "HorseRiding",
    MOUNTING_HORSE = "HorseMountingHorse",
    DISMOUNT_STARTED = "HorseDismountStarted",
    NO_CANCEL = "HorseNoCancel",

    HAS_REINS = "HorseHasReins",

    EATING = "HorseEating",
    EATING_HAND = "HorseEatingHand",
    HURT = "HorseHurt",
    DEATH = "HorseDeath",
    
    EQUIP_FINISHED = "HorseEquipFinished",

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
    GENE_CARRYWEIGHT = "HorseGeneCarryWeight"
}

return AnimationVariable