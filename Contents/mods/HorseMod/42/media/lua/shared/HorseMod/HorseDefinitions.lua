---@namespace HorseMod

---REQUIREMENTS
local HorseUtils = require("HorseMod/Utils")

local HorseDefinitions = {
    SHORT_NAMES = {
        AQHP = "american_quarter", -- American Quarter Horse Paint
        AP = "american_paint", -- American Paint
        GDA = "appaloosa", -- Appaloosa
        T = "thoroughbred", -- Thoroughbred
        AQHBR = "american_quarter_blue_roan", -- American Quarter Horse Blue Roan
        LPA = "leopard_appaloosa", -- Leopard Appaloosa
        APHO = "american_paint_horse_overo", -- American Paint Horse Overo
        FBG = "flea_bitten_grey", -- Flea Bitten Grey
    },
    PATHS = {
        texture = "HorseMod/Horse{shortName}",
        textureMale = "HorseMod/Horse{shortName}",
        rottenTexture = "HorseMod/Horse{shortName}",
        textureBaby = "HorseMod/Horse{shortName}",
        invIconMale = "media/textures/Item_body/Horse{shortName}_Foal.png",
        invIconFemale = "media/textures/Item_body/Horse{shortName}_Foal.png",
        invIconBaby = "media/textures/Item_body/Horse{shortName}_Foal.png",
        invIconMaleDead = "media/textures/Item_body/Horse{shortName}_Dead.png",
        invIconFemaleDead = "media/textures/Item_body/Horse{shortName}_Dead.png",
        invIconBabyDead = "media/textures/Item_body/Horse{shortName}_Foal_Dead.png",
    }
}

-- define the growth stages
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

-- define the breeds
local breeds = {}
for shortName, id in pairs(HorseDefinitions.SHORT_NAMES) do
    DebugLog.log("")
    DebugLog.log(shortName.."    "..id)
    local breed = {name = id}
    for key, path in pairs(HorseDefinitions.PATHS) do
        local formattedPath = HorseUtils.formatTemplate(path, {shortName = shortName})
        breed[key] = formattedPath
        DebugLog.log(key.."    ".. formattedPath)
    end
    breeds[id] = breed
end
AnimalDefinitions.breeds["horse"] = {breeds = breeds} -- retarded naming scheme from the game, lovely

-- define the genome
AnimalDefinitions.genome["horse"] = {
    ---@enum Genes
    genes = {
        meatRatio = "meatRatio",
        maxWeight = "maxWeight",
        lifeExpectancy = "lifeExpectancy",
        resistance = "resistance",
        strength = "strength",
        hungerResistance = "hungerResistance",
        thirstResistance = "thirstResistance",
        aggressiveness = "aggressiveness",
        ageToGrow = "ageToGrow",
        fertility = "fertility",
        stress = "stress",
        speed = "speed",
        stamina = "stamina",
        carryWeight = "carryWeight"
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
