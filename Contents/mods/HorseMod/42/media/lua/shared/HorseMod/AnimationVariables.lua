---@namespace HorseMod

---@enum AnimationVariables
return {
    --- Must always be true on all horses for their animations to play properly.
    IS_HORSE = "isHorse",
    WALK = "HorseWalk",
    GALLOP = "HorseGallop",
    TROT = "HorseTrot",
    JUMP = "HorseJump",
    DYING = "HorseDying",

    -- Activates mounted player animations while true
    RIDING_HORSE = "RidingHorse",
    MOUNTING_HORSE = "MountingHorse",
    MOUNT_FINISHED = "MountFinished",
    DISMOUNT_STARTED = "DismountStarted",
    DISMOUNT_FINISHED = "DismountFinished",

    HAS_REINS = "HasReins",

    EATING = "HorseEating",
    EATING_HAND = "HorseEatingHand",
    HURT = "HorseHurt",
    DEATH = "HorseDeath",
    
    EQUIP_FINISHED = "EquipFinished",

    KICK_LEFT = "kickLeft",
    KICK_RIGHT = "kickRight",
    IDLE_KICKING = "idleKicking",
    MOVE_KICKING = "moveKicking",

    WALK_SPEED = "HorseWalkSpeed",
    TROT_SPEED = "HorseTrotSpeed",
    RUN_SPEED = "HorseRunSpeed",
    -- Multiplier to the horse's speed from genetics
    GENE_SPEED = "geneSpeed",
    -- unused
    GENE_STRENGTH = "geneStrength",
    -- unused
    GENE_STAMINA = "geneStamina",
    -- unused
    GENE_CARRYWEIGHT = "geneCarryWeight"
}