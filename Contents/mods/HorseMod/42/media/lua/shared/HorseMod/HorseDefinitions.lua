AnimalDefinitions.stages["horse"] = {
    stages = {
        ["filly"] = {
            ageToGrow = 2 * 30, -- we probably won't have a filly model so check what happens if this is set to 0
            nextStage = "mare",
            nextStageMale = "stallion",
            minWeight = 0.1,
            maxWeight = 0.25
        },
        ["mare"] = {
            ageToGrow = 2 * 30,
            minWeight = 0.25,
            maxWeight = 0.5
        },
        ["stallion"] = {
            ageToGrow = 2 * 30,
            minWeight = 0.25,
            maxWeight = 0.5
        }
    }
}

AnimalDefinitions.genome["horse"] = {
    genes = {
        ["meatRatio"] = "meatRatio",
        ["maxWeight"] = "maxWeight",
        ["lifeExpectancy"] = "lifeExpectancy",
        ["resistance"] = "resistance",
        ["strength"] = "strength",
        ["hungerResistance"] = "hungerResistance",
        ["thirstResistance"] = "thirstResistance",
        ["aggressiveness"] = "aggressiveness",
        ["ageToGrow"] = "ageToGrow",
        ["fertility"] = "fertility",
        ["stress"] = "stress",
        ["speed"] = "speed",
        ["stamina"] = "stamina",
        ["carryWeight"] = "carryWeight"
    }
}

AnimalDefinitions.breeds["horse"] = {
    breeds = {
        ["american_quarter"] = {
            name = "american_quarter",
            texture = "HorseMod/HorseAQHP",
            textureMale = "HorseMod/HorseAQHP",
            rottenTexture = "HorseMod/HorseAQHP",
            textureBaby = "HorseMod/HorseAQHP",
            invIconMale = "media/textures/Item_body/HorseAQHP_Foal.png",
            invIconFemale = "media/textures/Item_body/HorseAQHP_Foal.png",
            invIconBaby = "media/textures/Item_body/HorseAQHP_Foal.png",
            invIconMaleDead = "media/textures/Item_body/HorseAQHP_Dead.png",
            invIconFemaleDead = "media/textures/Item_body/HorseAQHP_Dead.png",
            invIconBabyDead = "media/textures/Item_body/HorseAQHP_Foal_Dead.png",
        },
        ["american_paint"] = {
            name = "american_paint",
            texture = "HorseMod/HorseAP",
            textureMale = "HorseMod/HorseAP",
            rottenTexture = "HorseMod/HorseAP",
            textureBaby = "HorseMod/HorseAP",
            invIconMale = "media/textures/Item_body/HorseAP_Foal.png",
            invIconFemale = "media/textures/Item_body/HorseAP_Foal.png",
            invIconBaby = "media/textures/Item_body/HorseAP_Foal.png",
            invIconMaleDead = "media/textures/Item_body/HorseAP_Dead.png",
            invIconFemaleDead = "media/textures/Item_body/HorseAP_Dead.png",
            invIconBabyDead = "media/textures/Item_body/HorseAP_Foal_Dead.png",
        },
        ["appaloosa"] = {
            name = "appaloosa",
            texture = "HorseMod/HorseGDA",
            textureMale = "HorseMod/HorseGDA",
            rottenTexture = "HorseMod/HorseGDA",
            textureBaby = "HorseMod/HorseGDA",
            invIconMale = "media/textures/Item_body/HorseGDA_Foal.png",
            invIconFemale = "media/textures/Item_body/HorseGDA_Foal.png",
            invIconBaby = "media/textures/Item_body/HorseGDA_Foal.png",
            invIconMaleDead = "media/textures/Item_body/HorseGDA_Dead.png",
            invIconFemaleDead = "media/textures/Item_body/HorseGDA_Dead.png",
            invIconBabyDead = "media/textures/Item_body/HorseGDA_Foal_Dead.png",
        },
        ["thoroughbred"] = {
            name = "thoroughbred",
            texture = "HorseMod/HorseT",
            textureMale = "HorseMod/HorseT",
            rottenTexture = "HorseMod/HorseT",
            textureBaby = "HorseMod/HorseT",
            invIconMale = "media/textures/Item_body/HorseT_Foal.png",
            invIconFemale = "media/textures/Item_body/HorseT_Foal.png",
            invIconBaby = "media/textures/Item_body/HorseT_Foal.png",
            invIconMaleDead = "media/textures/Item_body/HorseT_Dead.png",
            invIconFemaleDead = "media/textures/Item_body/HorseT_Dead.png",
            invIconBabyDead = "media/textures/Item_body/HorseT_Foal_Dead.png",
        },
        ["blue_roan"] = {
            name = "blue_roan",
            texture = "HorseMod/HorseAQHBR",
            textureMale = "HorseMod/HorseAQHBR",
            rottenTexture = "HorseMod/HorseAQHBR",
            textureBaby = "HorseMod/HorseAQHBR",
            invIconMale = "media/textures/Item_body/HorseAQHBR_Foal.png",
            invIconFemale = "media/textures/Item_body/HorseAQHBR_Foal.png",
            invIconBaby = "media/textures/Item_body/HorseAQHBR_Foal.png",
            invIconMaleDead = "media/textures/Item_body/HorseAQHBR_Dead.png",
            invIconFemaleDead = "media/textures/Item_body/HorseAQHBR_Dead.png",
            invIconBabyDead = "media/textures/Item_body/HorseAQHBR_Foal_Dead.png",
        },
        ["spotted_appaloosa"] = {
            name = "spotted_appaloosa",
            texture = "HorseMod/HorseLPA",
            textureMale = "HorseMod/HorseLPA",
            rottenTexture = "HorseMod/HorseLPA",
            textureBaby = "HorseMod/HorseLPA",
            invIconMale = "media/textures/Item_body/HorseLPA_Foal.png",
            invIconFemale = "media/textures/Item_body/HorseLPA_Foal.png",
            invIconBaby = "media/textures/Item_body/HorseLPA_Foal.png",
            invIconMaleDead = "media/textures/Item_body/HorseLPA_Dead.png",
            invIconFemaleDead = "media/textures/Item_body/HorseLPA_Dead.png",
            invIconBabyDead = "media/textures/Item_body/HorseLPA_Foal_Dead.png",
        },
        ["american_paint_overo"] = {
            name = "american_paint_overo",
            texture = "HorseMod/HorseAPHO",
            textureMale = "HorseMod/HorseAPHO",
            rottenTexture = "HorseMod/HorseAPHO",
            textureBaby = "HorseMod/HorseAPHO",
            invIconMale = "media/textures/Item_body/HorseAPHO_Foal.png",
            invIconFemale = "media/textures/Item_body/HorseAPHO_Foal.png",
            invIconBaby = "media/textures/Item_body/HorseAPHO_Foal.png",
            invIconMaleDead = "media/textures/Item_body/HorseAPHO_Dead.png",
            invIconFemaleDead = "media/textures/Item_body/HorseAPHO_Dead.png",
            invIconBabyDead = "media/textures/Item_body/HorseAPHO_Foal_Dead.png",
        },
        ["flea_bitten_grey"] = {
            name = "flea_bitten_grey",
            texture = "HorseMod/HorseFBG",
            textureMale = "HorseMod/HorseFBG",
            rottenTexture = "HorseMod/HorseFBG",
            textureBaby = "HorseMod/HorseFBG",
            invIconMale = "media/textures/Item_body/HorseFBG_Foal.png",
            invIconFemale = "media/textures/Item_body/HorseFBG_Foal.png",
            invIconBaby = "media/textures/Item_body/HorseFBG_Foal.png",
            invIconMaleDead = "media/textures/Item_body/HorseFBG_Dead.png",
            invIconFemaleDead = "media/textures/Item_body/HorseFBG_Dead.png",
            invIconBabyDead = "media/textures/Item_body/HorseFBG_Foal_Dead.png",
        },
    }
}

-- TODO: a lot of this is just copied from deer

AnimalDefinitions.animals["filly"] = {
    -- RENDERING
    bodyModel = "HorseMod.Horse",
    bodyModelSkel = "HorseMod.HorseSkeleton",
    textureSkeleton = "HorseMod/HorseSkeletonDry",
    textureSkeletonBloody = "HorseMod/HorseSkeletonBloody",
    bodyModelSkelNoHead = "HorseMod.HorseSkeletonHeadless",
    animset = "buck",
    modelscript = "HorseMod.Horse",
    carcassItem = "HorseMod.Horse",
    bodyModelHeadless = "HorseMod.HorseHeadless",
    textureSkinned = "HorseMod/HorseSkinned",
    ropeBone = "DEF_Neck1",
    shadoww = 1.5,
    shadowfm = 4.5,
    shadowbm = 4.5,

    -- CORE
    breeds = copyTable(AnimalDefinitions.breeds["horse"].breeds),
    stages = AnimalDefinitions.stages["horse"].stages,
    genes = AnimalDefinitions.genome["horse"].genes,

    -- MATING
    minAge = AnimalDefinitions.stages["horse"].stages["filly"].ageToGrow,

    -- BEHAVIOR
    fleeZombies = true,
    wanderMul = 500,
    sitRandomly = true,
    idleTypeNbr = 3,
    canBeAttached = true,
    wild = false,
    spottingDist = 19,
    group = "horse",
    canBeAlerted = false,
    canBeDomesticated = true,
    canThump = false,
    eatGrass = true,
    canBePet = true,
    idleEmoteChance = 600,
    eatFromMother = true,
    periodicRun = true,

    -- COMBAT
    dontAttackOtherMale = true,
    attackDist = 2,
    knockdownAttack = true,
    attackIfStressed = true,
    attackBack = true,

    -- STATS
    ---- general
    turnDelta = 0.65,
    trailerBaseSize = 180,
    minEnclosureSize = 120,
    idleSoundVolume = 0.2,
    ---- size
    collisionSize = 0.35,
    minSize = 0.4,
    maxSize = 0.4,
    animalSize = 0.3,
    baseEncumbrance = 180,
    minWeight = 120,
    maxWeight = 450,
    corpseSize = 3,
    ---- food
    eatTypeTrough = "AnimalFeed,Grass,Hay,Vegetables,Fruits",
    hungerMultiplier = 0.0035,
    thirstMultiplier = 0.006,
    healthLossMultiplier = 0.01,
    thirstHungerTrigger = 0.3,
    distToEat = 1,
    hungerBoost = 3,
    ---- death
    minBlood = 1200,
    maxBlood = 4000,
}

AnimalDefinitions.animals["stallion"] = {
    -- RENDERING
    bodyModel = "HorseMod.Horse",
    bodyModelSkel = "HorseMod.HorseSkeleton",
    textureSkeleton = "HorseMod/HorseSkeletonDry",
    textureSkeletonBloody = "HorseMod/HorseSkeletonBloody",
    bodyModelSkelNoHead = "HorseMod.HorseSkeletonHeadless",
    animset = "buck",
    modelscript = "HorseMod.Horse",
    carcassItem = "HorseMod.Horse",
    bodyModelHeadless = "HorseMod.HorseHeadless",
    textureSkinned = "HorseMod/HorseSkinned",
    ropeBone = "DEF_Neck1",
    shadoww = 1.5,
    shadowfm = 4.5,
    shadowbm = 4.5,

    -- CORE
    breeds = copyTable(AnimalDefinitions.breeds["horse"].breeds),
    stages = AnimalDefinitions.stages["horse"].stages,
    genes = AnimalDefinitions.genome["horse"].genes,

    -- MATING
    male = true,
    mate = "mare",
    babyType = "filly",
    minAge = AnimalDefinitions.stages["horse"].stages["filly"].ageToGrow,
    minAgeForBaby = 12 * 30,
    maxAgeGeriatric = 12 * 20 * 30,

    -- BEHAVIOR
    fleeZombies = true,
    wanderMul = 500,
    sitRandomly = true,
    idleTypeNbr = 3,
    canBeAttached = true,
    wild = false,
    spottingDist = 19,
    group = "horse",
    canBeAlerted = false,
    canBeDomesticated = true,
    canThump = false,
    eatGrass = true,
    canBePet = true,
    idleEmoteChance = 900,

    -- COMBAT
    dontAttackOtherMale = true,
    attackDist = 2,
    knockdownAttack = true,
    attackIfStressed = true,
    attackBack = true,

    -- STATS
    ---- general
    turnDelta = 0.65,
    trailerBaseSize = 300,
    minEnclosureSize = 120,
    idleSoundVolume = 0.2,
    ---- size
    collisionSize = 0.35,
    minSize = 0.6,
    maxSize = 0.6,
    animalSize = 0.5,
    baseEncumbrance = 180,
    minWeight = 380,
    maxWeight = 1000,
    corpseSize = 5,
    ---- food
    eatTypeTrough = "AnimalFeed,Grass,Hay,Vegetables,Fruits",
    hungerMultiplier = 0.0035,
    thirstMultiplier = 0.006,
    healthLossMultiplier = 0.01,
    thirstHungerTrigger = 0.3,
    distToEat = 1,
    hungerBoost = 3,
    ---- death
    minBlood = 1200,
    maxBlood = 4000,
}

AnimalDefinitions.animals["mare"] = {
    -- RENDERING
    bodyModel = "HorseMod.Horse",
    bodyModelSkel = "HorseMod.HorseSkeleton",
    textureSkeleton = "HorseMod/HorseSkeletonDry",
    textureSkeletonBloody = "HorseMod/HorseSkeletonBloody",
    bodyModelSkelNoHead = "HorseMod.HorseSkeletonHeadless",
    animset = "buck",
    modelscript = "HorseMod.Horse",
    carcassItem = "HorseMod.Horse",
    bodyModelHeadless = "HorseMod.HorseHeadless",
    textureSkinned = "HorseMod/HorseSkinned",
    ropeBone = "DEF_Neck1",
    shadoww = 1.5,
    shadowfm = 4.5,
    shadowbm = 4.5,

    -- CORE
    breeds = copyTable(AnimalDefinitions.breeds["horse"].breeds),
    stages = AnimalDefinitions.stages["horse"].stages,
    genes = AnimalDefinitions.genome["horse"].genes,

    -- MATING
    female = true,
    mate = "stallion",
    babyType = "filly",
    minAge = AnimalDefinitions.stages["horse"].stages["filly"].ageToGrow,
    minAgeForBaby = 12 * 30,
    maxAgeGeriatric = 12 * 20 * 30,
    pregnantPeriod = 11 * 30,
    timeBeforeNextPregnancy = 60,

    -- BEHAVIOR
    fleeZombies = true,
    wanderMul = 500,
    sitRandomly = true,
    idleTypeNbr = 3,
    canBeAttached = true,
    wild = false,
    spottingDist = 19,
    group = "horse",
    canBeAlerted = false,
    canBeDomesticated = true,
    canThump = false,
    eatGrass = true,
    canBePet = true,
    idleEmoteChance = 900,

    -- COMBAT
    dontAttackOtherMale = true,
    attackDist = 2,
    knockdownAttack = true,
    attackIfStressed = true,
    attackBack = true,

    -- STATS
    ---- general
    turnDelta = 0.65,
    trailerBaseSize = 300,
    minEnclosureSize = 120,
    idleSoundVolume = 0.2,
    ---- size
    collisionSize = 0.35,
    minSize = 0.6,
    maxSize = 0.6,
    animalSize = 0.5,
    baseEncumbrance = 180,
    minWeight = 380,
    maxWeight = 1000,
    corpseSize = 5,
    ---- food
    eatTypeTrough = "AnimalFeed,Grass,Hay,Vegetables,Fruits",
    hungerMultiplier = 0.0035,
    thirstMultiplier = 0.006,
    healthLossMultiplier = 0.01,
    thirstHungerTrigger = 0.3,
    distToEat = 1,
    hungerBoost = 3,
    ---- death
    minBlood = 1200,
    maxBlood = 4000,
}

local AVATAR_DEFINITION = {
    zoom = -20,
    xoffset = 0,
    yoffset = -1,
    avatarWidth = 180,
    avatarDir = IsoDirections.SE,
    trailerDir = IsoDirections.SW,
    trailerZoom = -20,
    trailerXoffset = 0,
    trailerYoffset = 0,
    hook = true,
    butcherHookZoom = -20,
    butcherHookXoffset = 0,
    butcherHookYoffset = 0.5,
    animalPositionSize = 0.6,
    animalPositionX = 0,
    animalPositionY = 0.5,
    animalPositionZ = 0.7
}

AnimalAvatarDefinition["stallion"] = AVATAR_DEFINITION
AnimalAvatarDefinition["mare"] = AVATAR_DEFINITION
AnimalAvatarDefinition["filly"] = AVATAR_DEFINITION
