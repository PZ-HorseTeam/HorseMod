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

-- TODO: research appropriate horse breeds
-- breeds should have different forced genes
AnimalDefinitions.breeds["horse"] = {
    breeds = {
        ["american_quarter"] = {
            name = "american_quarter",
            -- TODO: split these into separate breeds
            -- i didn't do this because i wasn't sure which textures are which breeds
            texture = "HorseMod/HorseAQHP",
            textureMale = "HorseMod/HorseAQHP",
            rottenTexture = "HorseMod/HorseAQHP",
            textureBaby = "HorseMod/HorseAQHP",
            invIconMale = "Item_DeerMale_Dead",
            invIconFemale = "Item_DeerFemale_Dead",
            invIconBaby = "Item_DeerFawn_Dead",
            invIconMaleDead = "Item_DeerMale_Dead",
            invIconFemaleDead = "Item_DeerFemale_Dead",
            invIconBabyDead = "Item_DeerFawn_Dead",
        },
        ["american_paint"] = {
            name = "american_paint",
            -- TODO: split these into separate breeds
            -- i didn't do this because i wasn't sure which textures are which breeds
            texture = "HorseMod/HorseAP",
            textureMale = "HorseMod/HorseAP",
            rottenTexture = "HorseMod/HorseAP",
            textureBaby = "HorseMod/HorseAP",
            invIconMale = "Item_DeerMale_Dead",
            invIconFemale = "Item_DeerFemale_Dead",
            invIconBaby = "Item_DeerFawn_Dead",
            invIconMaleDead = "Item_DeerMale_Dead",
            invIconFemaleDead = "Item_DeerFemale_Dead",
            invIconBabyDead = "Item_DeerFawn_Dead",
        },
        ["appaloosa"] = {
            name = "appaloosa",
            -- TODO: split these into separate breeds
            -- i didn't do this because i wasn't sure which textures are which breeds
            texture = "HorseMod/HorseGBA",
            textureMale = "HorseMod/HorseGBA",
            rottenTexture = "HorseMod/HorseGBA",
            textureBaby = "HorseMod/HorseGBA",
            invIconMale = "Item_DeerMale_Dead",
            invIconFemale = "Item_DeerFemale_Dead",
            invIconBaby = "Item_DeerFawn_Dead",
            invIconMaleDead = "Item_DeerMale_Dead",
            invIconFemaleDead = "Item_DeerFemale_Dead",
            invIconBabyDead = "Item_DeerFawn_Dead",
        },
        ["steve_the_horse"] = {
            name = "steve_the_horse",
            -- TODO: split these into separate breeds
            -- i didn't do this because i wasn't sure which textures are which breeds
            texture = "HorseMod/Horse",
            textureMale = "HorseMod/Horse",
            rottenTexture = "HorseMod/Horse",
            textureBaby = "HorseMod/Horse",
            invIconMale = "Item_DeerMale_Dead",
            invIconFemale = "Item_DeerFemale_Dead",
            invIconBaby = "Item_DeerFawn_Dead",
            invIconMaleDead = "Item_DeerMale_Dead",
            invIconFemaleDead = "Item_DeerFemale_Dead",
            invIconBabyDead = "Item_DeerFawn_Dead",
        }
    }
}

-- TODO: a lot of this is just copied from deer

AnimalDefinitions.animals["filly"] = {
    -- RENDERING
    bodyModel = "HorseMod.Horse",
    bodyModelSkel = "HorseMod.HorseSkeleton",
    textureSkeleton = "HorseMod.Horse",
    textureSkeletonBloody = "HorseMod.Horse",
    bodyModelSkelNoHead = "HorseMod.HorseSkeletonHeadless",
    animset = "buck",
    modelscript = "HorseMod.Horse",
    carcassItem = "HorseMod.Horse",
    bodyModelHeadless = "HorseMod.HorseHeadless",
    textureSkinned = "HorseMod.Horse",
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
    turnDelta = 0.8,
    trailerBaseSize = 300,
    minEnclosureSize = 40,
    idleSoundVolume = 0.2,
    ---- size
    collisionSize = 0.6,
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

AnimalDefinitions.animals["stallion"] = {
    -- RENDERING
    bodyModel = "HorseMod.Horse",
    bodyModelSkel = "HorseMod.HorseSkeleton",
    textureSkeleton = "HorseMod.Horse",
    textureSkeletonBloody = "HorseMod.Horse",
    bodyModelSkelNoHead = "HorseMod.HorseSkeletonHeadless",
    animset = "buck",
    modelscript = "HorseMod.Horse",
    carcassItem = "HorseMod.Horse",
    bodyModelHeadless = "HorseMod.HorseHeadless",
    textureSkinned = "HorseMod.Horse",
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
    turnDelta = 0.8,
    trailerBaseSize = 300,
    minEnclosureSize = 40,
    idleSoundVolume = 0.2,
    ---- size
    collisionSize = 0.6,
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
    textureSkeleton = "HorseMod.Horse",
    textureSkeletonBloody = "HorseMod.Horse",
    bodyModelSkelNoHead = "HorseMod.HorseSkeletonHeadless",
    animset = "buck",
    modelscript = "HorseMod.Horse",
    carcassItem = "HorseMod.Horse",
    bodyModelHeadless = "HorseMod.HorseHeadless",
    textureSkinned = "HorseMod.Horse",
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
    turnDelta = 0.8,
    trailerBaseSize = 300,
    minEnclosureSize = 40,
    idleSoundVolume = 0.2,
    ---- size
    collisionSize = 0.6,
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

local stallion_sounds = {
    -- eat_grass = { name = "HorseEatingGrass", slot = "voice", priority = 100 },
	-- death = { name = "HorseDeath", slot = "voice", priority = 100 },
	fallover = { name = "AnimalFoleyBuckBodyfall" },
	-- idle = { name = "HorseIdleSnort", intervalMin = 10, intervalMax = 20, slot = "voice" },
	-- pain = { name = "HorsePain", slot = "voice", priority = 50 },
	pick_up = { name = "PickUpAnimalDeer", slot = "voice", priority = 1 },
	pick_up_corpse = { name = "PickUpAnimalDeadDeer" },
	put_down = { name = "PutDownAnimalDeer", slot = "voice", priority = 1 },
	put_down_corpse = { name = "PutDownAnimalDeadDeer" },
	-- stressed = { name = "HorseStressed", intervalMin = 5, intervalMax = 10, slot = "voice" },
    gallopConcrete = { name = "HorseGallopConcrete", slot = "hoof" },
    trotConcrete = { name = "HorseTrotConcrete", slot = "hoof" },
    walkConcrete = { name = "HorseWalkConcrete", slot = "hoof" },
    gallopDirt = { name = "HorseGallopDirt", slot = "hoof" },
    gallopAI = { name = "AnimalFootstepsBuckRun", slot = "hoof" },
    trotDirt = { name = "HorseTrotDirt", slot = "hoof" },
    walkDirt = { name = "HorseWalkDirt", slot = "hoof" },
    walkBack = { name = "AnimalFootstepsBuckWalkBack" },
	walkFront = { name = "AnimalFootstepsBuckWalkFront" },
}
AnimalDefinitions.animals["stallion"].breeds["american_quarter"].sounds = stallion_sounds

local mare_sounds = {
    -- eat_grass = { name = "HorseEatingGrass", slot = "voice", priority = 100 },
	-- death = { name = "HorseDeath", slot = "voice", priority = 100 },
	fallover = { name = "AnimalFoleyDoeBodyfall" },
	-- idle = { name = "HorseIdleSnort", intervalMin = 10, intervalMax = 20, slot = "voice" },
	-- pain = { name = "HorsePain", slot = "voice", priority = 50 },
	pick_up = { name = "PickUpAnimalDeer", slot = "voice", priority = 1 },
	pick_up_corpse = { name = "PickUpAnimalDeadDeer" },
	put_down = { name = "PutDownAnimalDeer", slot = "voice", priority = 1 },
	put_down_corpse = { name = "PutDownAnimalDeadDeer" },
	-- stressed = { name = "HorseStressed", intervalMin = 5, intervalMax = 10, slot = "voice" },
    gallopConcrete = { name = "HorseGallopConcrete", slot = "hoof" },
    trotConcrete = { name = "HorseTrotConcrete", slot = "hoof" },
    walkConcrete = { name = "HorseWalkConcrete", slot = "hoof" },
    gallopDirt = { name = "HorseGallopDirt", slot = "hoof" },
    gallopAI = { name = "AnimalFootstepsBuckRun", slot = "hoof" },
    trotDirt = { name = "HorseTrotDirt", slot = "hoof" },
    walkDirt = { name = "HorseWalkDirt", slot = "hoof" },
    walkBack = { name = "AnimalFootstepsBuckWalkBack" },
	walkFront = { name = "AnimalFootstepsBuckWalkFront" },
}
AnimalDefinitions.animals["mare"].breeds["american_quarter"].sounds = mare_sounds

local filly_sounds = {
    -- eat_grass = { name = "HorseEatingGrass", slot = "voice", priority = 100 },
	-- death = { name = "HorseDeath", slot = "voice", priority = 100 },
	fallover = { name = "AnimalFoleyFawnBodyfall" },
	idle = { name = "HorseIdleSnort", intervalMin = 6, intervalMax = 12, slot = "voice" },
	pain = { name = "HorsePain", slot = "voice", priority = 50 },
	pick_up = { name = "PickUpAnimalFawn", slot = "voice", priority = 1 },
	pick_up_corpse = { name = "PickUpAnimalDeadFawn" },
	put_down = { name = "PutDownAnimalFawn", slot = "voice", priority = 1 },
	put_down_corpse = { name = "PutDownAnimalDeadFawn" },
	stressed = { name = "HorseStressed", intervalMin = 3, intervalMax = 8, slot = "voice" },
    gallopConcrete = { name = "HorseGallopConcrete", slot = "hoof" },
    trotConcrete = { name = "HorseTrotConcrete", slot = "hoof" },
    walkConcrete = { name = "HorseWalkConcrete", slot = "hoof" },
    gallopDirt = { name = "HorseGallopDirt", slot = "hoof" },
    gallopAI = { name = "AnimalFootstepsBuckRun", slot = "hoof" },
    trotDirt = { name = "HorseTrotDirt", slot = "hoof" },
    walkDirt = { name = "HorseWalkDirt", slot = "hoof" },
    walkBack = { name = "AnimalFootstepsBuckWalkBack" },
	walkFront = { name = "AnimalFootstepsBuckWalkFront" },
}
AnimalDefinitions.animals["filly"].breeds["american_quarter"].sounds = filly_sounds

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
    butcherHookYoffset = 0,
    animalPositionSize = 0.6,
    animalPositionX = 0,
    animalPositionY = 0.5,
    animalPositionZ = 0.7
}

AnimalAvatarDefinition["stallion"] = AVATAR_DEFINITION
AnimalAvatarDefinition["mare"] = AVATAR_DEFINITION
AnimalAvatarDefinition["filly"] = AVATAR_DEFINITION
