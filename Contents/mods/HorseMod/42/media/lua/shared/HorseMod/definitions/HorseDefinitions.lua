---@namespace HorseMod

---REQUIREMENTS
local HorseUtils = require("HorseMod/Utils")

local HorseDefinitions = {
    SHORT_NAMES = {
        -- American Quarter
        "AmericanQuarterPalomino", -- Palomino
        "AmericanQuarterBlueRoan", -- Blue Roan
        
        -- American Paint
        "AmericanPaintTobiano", -- Tobiano
        "AmericanPaintOvero", -- Overo
        
        -- Appaloosa
        "AppaloosaGrullaBlanket", -- Grulla Blanket
        "AppaloosaLeopard", -- Leopard
        
        -- Thoroughbred
        "ThoroughbredBay", -- Bay
        "ThoroughbredFleaBittenGrey", -- Flea Bitten Grey
    },
    PATHS = {
        texture = "HorseMod/Horse_{id}",
        textureMale = "HorseMod/Horse_{id}",
        rottenTexture = "HorseMod/Horse_{id}",
        textureBaby = "HorseMod/Horse_{id}",
        invIconMale = "media/textures/Item_body/Horse_{id}_Foal.png",
        invIconFemale = "media/textures/Item_body/Horse_{id}_Foal.png",
        invIconBaby = "media/textures/Item_body/Horse_{id}_Foal.png",
        invIconMaleDead = "media/textures/Item_body/Horse_{id}_Dead.png",
        invIconFemaleDead = "media/textures/Item_body/Horse_{id}_Dead.png",
        invIconBabyDead = "media/textures/Item_body/Horse_{id}_Foal_Dead.png",
    },
    AVATAR_DEFINITION = {
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
    },
}





-- define the growth stages
AnimalDefinitions.stages["horse"] = {
    stages = {
        ["filly"] = {
            ageToGrow = 2 * 30,
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


HorseDefinitions.IS_ADULT = {
    ["stallion"] = true,
    ["mare"] = true,
    ["filly"] = false,
}

HorseDefinitions.ANIMALS_DATA = {
    --- data applied to every horses, adult or not
    _DEFAULT = {
        bodyModelSkel = "HorseMod.HorseSkeleton",
        textureSkeleton = "HorseMod/HorseSkeletonDry",
        textureSkeletonBloody = "HorseMod/HorseSkeletonBloody",
        bodyModelSkelNoHead = "HorseMod.HorseSkeletonHeadless",
        animset = "buck",
        bodyModelHeadless = "HorseMod.HorseHeadless",
        textureSkinned = "HorseMod/HorseSkinned",
        ropeBone = "DEF_Neck1",
        shadoww = 1.5,
        shadowfm = 3,
        shadowbm = 3,

        -- CORE
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

        -- COMBAT
        dontAttackOtherMale = true,
        attackDist = 2,
        knockdownAttack = true,
        attackIfStressed = true,
        attackBack = true,

        -- STATS
        --- general
        turnDelta = 0.65,
        minEnclosureSize = 120,
        idleSoundVolume = 0.2,
        --- size
        collisionSize = 0.35,
        baseEncumbrance = 180,
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
    },

    -- adult horse specific data
    _DEFAULT_ADULT = {
        bodyModel = "HorseMod.Horse",
        modelscript = "HorseMod.Horse",
        carcassItem = "HorseMod.Horse",
        -- MATING
        babyType = "filly",
        minAgeForBaby = 12 * 30,
        maxAgeGeriatric = 12 * 20 * 30,

        -- BEHAVIOR
        idleEmoteChance = 900,

        -- STATS
        ---- general
        trailerBaseSize = 300,
        --- size
        minSize = 0.6,
        maxSize = 0.6,
        animalSize = 0.5,
        minWeight = 380,
        maxWeight = 1000,
        corpseSize = 5,
    },

    -- adult, male, female data
    ["filly"] = {
        bodyModel = "HorseMod.Foal",
        modelscript = "HorseMod.Foal",
        carcassItem = "HorseMod.Foal",
        -- BEHAVIOR
        idleEmoteChance = 600,
        eatFromMother = true,
        periodicRun = true,

        -- STATS
        ---- general
        trailerBaseSize = 180,
        --- size
        minSize = 0.4,
        maxSize = 0.4,
        animalSize = 0.3,
        minWeight = 120,
        maxWeight = 450,
        corpseSize = 3,
    },

    ["stallion"] = {
        -- MATING
        male = true,
        mate = "mare",
    },

    ["mare"] = {
        -- MATING
        female = true,
        mate = "stallion",
    },
}

local EXP_HORSE = 25
local EXP_FILLY = 15

HorseDefinitions.PARTS = {
    _DEFAULT = {
        skull = "HorseMod.Horse_Skull",
    },

    _DEFAULT_ADULT = {
        parts = {
            {item = "HorseMod.Horse_Steak", minNb = 10, maxNb = 18},
            {item = "HorseMod.Horse_Loin", minNb = 10, maxNb = 18},
            {item = "Base.AnimalSinew", minNb = 3, maxNb = 7},
            {item = "HorseMod.Horse_Hoof", nb = 4},
        },
        bones = {
            {item = "Base.AnimalBone", minNb = 7, maxNb = 10},
            {item = "Base.LargeAnimalBone", minNb = 3, maxNb = 5},
        },
        leather = "HorseMod.HorseLeather_{id}_Full",
        xpPerItem = EXP_HORSE,
    },

    -- adult, male, female data
    ["filly"] = {
        parts = {
            {item = "HorseMod.Horse_Steak", minNb = 5, maxNb = 9},
            {item = "HorseMod.Horse_Loin", minNb = 5, maxNb = 9},
            {item = "Base.AnimalSinew", minNb = 1, maxNb = 3},
            {item = "HorseMod.Horse_Hoof", nb = 4},
        },
        bones = {
            {item = "Base.AnimalBone", minNb = 4, maxNb = 7},
        },
        head = "HorseMod.Foal_Head_{id}",
        leather = "HorseMod.",
        xpPerItem = EXP_FILLY,
    },

    ["stallion"] = {
        head = "HorseMod.Stallion_Head_{id}"
    },

    ["mare"] = {
        head = "HorseMod.Mare_Head_{id}"
    },
}







--- ==================================================== ---
--- APPLY THE ANIMAL DATA TO THE GAME ANIMAL DEFINITIONS ---
--- ==================================================== ---


-- simple utility function to copy data from `newData` to `data` by overriding common keys.
local function copyOver(data, newData)
    newData = copyTable(newData)
    for k,v in pairs(newData) do
        data[k] = v
    end
    return data
end

--- Hook to OnGameBoot to delay addition for other mods to modify the currently defined data
Events.OnGameBoot.Add(function()
    -- define the breeds
    -- associates the horse breeds to the paths formatted with their ID
    local breeds = {}
    for i = 1, #HorseDefinitions.SHORT_NAMES do
        local id = HorseDefinitions.SHORT_NAMES[i] --[[@as string EmmyLua going fucking schizo]]
        local breed = {name = id}
        for key, path in pairs(HorseDefinitions.PATHS) do
            local formattedPath = HorseUtils.formatTemplate(path, {id = id})
            breed[key] = formattedPath
        end
        breeds[id] = breed
    end
    AnimalDefinitions.breeds["horse"] = {breeds = breeds} -- retarded naming scheme from the game, lovely


    -- apply animal data
    local ANIMALS_DATA = HorseDefinitions.ANIMALS_DATA

    -- for each animal, copy the default data table, then apply the different data based on adult and growth stage
    for animalType, isAdult in pairs(HorseDefinitions.IS_ADULT) do
        -- retrieve the default animal data
        local data = copyTable(ANIMALS_DATA._DEFAULT)
        data.breeds = copyTable(AnimalDefinitions.breeds["horse"].breeds) -- copy horse breed data

    -- if adult, apply adult data
        if isAdult then
            data = copyOver(data, ANIMALS_DATA._DEFAULT_ADULT)
        end

        -- per animal type data
        data = copyOver(data, ANIMALS_DATA[animalType])

        -- save data
        AnimalDefinitions.animals[animalType] = data

        -- apply avatar definition
        AnimalAvatarDefinition[animalType] = HorseDefinitions.AVATAR_DEFINITION
    end


    -- parts data
    local PARTS = HorseDefinitions.PARTS
    for i = 1, #HorseDefinitions.SHORT_NAMES do
        local id = HorseDefinitions.SHORT_NAMES[i] --[[@as string EmmyLua going fucking schizo]]

        for animalType, isAdult in pairs(HorseDefinitions.IS_ADULT) do
            local data = copyTable(PARTS._DEFAULT)

            if isAdult then
                data = copyOver(data, PARTS._DEFAULT_ADULT)
            end

            data = copyOver(data, PARTS[animalType])

            -- format elements with id
            data.leather = HorseUtils.formatTemplate(data.leather, {id = id})
            data.head = HorseUtils.formatTemplate(data.head, {id = id})

            AnimalPartsDefinitions.animals[animalType .. id]  = data
        end
    end
end)




return HorseDefinitions