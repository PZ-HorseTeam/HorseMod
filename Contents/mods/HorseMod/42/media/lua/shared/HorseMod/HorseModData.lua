local HorseManager = require("HorseMod/HorseManager")
---@namespace HorseMod

---Used to access a kind of mod data defined for a horse such as containers, attachments and manes.
---@class ModDataKind<T: table>
---@field package name string Mod data subtable name.
---@field package initialiser? fun(horse:IsoAnimal,modData:table):nil Called when a horse loads in to ensure it's mod data are initialised.

local HorseModData = {
    ---@type table<string, ModDataKind<any>>
    modDataKinds = {},
}

local ANIMAL_MODDATA_KEY = "horseModData"

---@type table
local GLOBAL_MOD_DATA

Events.OnInitGlobalModData.Add(function()
    GLOBAL_MOD_DATA = ModData.getOrCreate("horsemod")
    GLOBAL_MOD_DATA.orphanedHorses = GLOBAL_MOD_DATA.orphanedHorses or {}
end)

---Retrieve all horse mod data.
---@param horse IsoAnimal
---@return table<string, table>
local function getAll(horse)
    local modData = horse:getModData()
    modData[ANIMAL_MODDATA_KEY] = modData[ANIMAL_MODDATA_KEY] or {}
    return modData[ANIMAL_MODDATA_KEY]
end

---Registers a new kind of mod data.
---@generic T
---@param name string Unique name of the mod data kind. This must be globally unique.
---@param initialiser (fun(horse:IsoAnimal,modData:Partial<T>):nil)? Function to initialise the mod data kind. This will be called every time the mod data is accessed.
---@return ModDataKind<T> kind
function HorseModData.register(name, initialiser)
    if HorseModData.modDataKinds[name] then
        if isDebugEnabled() then
            -- we only warn in debug mode because this may be caused by a file reload
            print("[HorseMod] WARN: adding ModDataKind with already seen name " .. name)
        else
            error("tried to register two ModDataKinds with same name " .. name)
        end
    end
    local kind = {
        name = name,
        initialiser = initialiser,
    }
    HorseModData.modDataKinds[name] = kind
    return kind
end

---Check if there is orphan mod data for the given horse and copy it back to the horse mod data.
---@param horse IsoAnimal
local function copyOrphanData(horse)
    -- try to find orphaned mod data
    local horseID = horse:getAnimalID()
    local orphanModData = GLOBAL_MOD_DATA.orphanedHorses[horseID]
    if not orphanModData then return end

    -- set the new mod data
    horse:getModData()[ANIMAL_MODDATA_KEY] = orphanModData
    GLOBAL_MOD_DATA.orphanedHorses[horseID] = nil
end

---Split the horse mod data from the horse and store it in the global mod data as a orphan mod data.
---This is usually needed when the horse gets removed from the world temporarly (e.g. when picked up by a player).
---@param horse IsoAnimal
function HorseModData.makeOrphan(horse)
    local horseID = horse:getAnimalID()
    GLOBAL_MOD_DATA.orphanedHorses[horseID] = copyTable(getAll(horse))
end

---Initialises all mod data kinds for the given horse.
---@param horse IsoAnimal
function HorseModData.initialize(horse)
    copyOrphanData(horse)
    local horseModData = getAll(horse)
    for name, kind in pairs(HorseModData.modDataKinds) do
        horseModData[name] = horseModData[name] or {}
        local kindModData = horseModData[name] --[[@as table goes crazy without it]]
        if kind.initialiser then
            kind.initialiser(horse, kindModData)
        end
    end
end

HorseManager.onHorseAdded:add(HorseModData.initialize)


---Returns mod data of a specific kind.
---@generic T
---@param horse IsoAnimal
---@param kind ModDataKind<T>
---@return T modData
function HorseModData.get(horse, kind)
    return getAll(horse)[kind.name]
end


return HorseModData