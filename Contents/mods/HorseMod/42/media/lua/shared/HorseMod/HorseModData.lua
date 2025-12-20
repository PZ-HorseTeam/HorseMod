---REQUIREMENTS
local HorseManager = require("HorseMod/HorseManager")

---@namespace HorseMod


---@class ModDataKind<T: table>
---@field package name string Mod data subtable name.
---@field package initialiser? fun(horse:IsoAnimal,modData:table):nil Called when a horse loads in to ensure it's mod data are initialised.


local HorseModData = {
    ---@type table<string, ModDataKind<any>>
    modDataKinds = {},
}


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

---Initialises all mod data kinds for the given horse.
---@param horse IsoAnimal
function HorseModData.initialize(horse)
    local modData = horse:getModData()
    modData.horseModData = modData.horseModData or {}
    local horseModData = modData.horseModData
    for name, kind in pairs(HorseModData.modDataKinds) do
        horseModData[name] = horseModData[name] or {}
        local kindModData = horseModData[name] --[[@as table goes crazy without it]]
        if kind.initialiser then
            kind.initialiser(horse, kindModData)
        end
    end
end

---Returns mod data of a specific kind.
---@generic T
---@param horse IsoAnimal
---@param kind ModDataKind<T>
---@return T modData
function HorseModData.get(horse, kind)
    local modData = horse:getModData()

    -- get the kind mod data
    local horseModData = modData.horseModData --[[@as table<string, T>]]
    local kindModData = horseModData[kind.name]
    
    return kindModData
end

HorseManager.onHorseAdded:add(HorseModData.initialize)


return HorseModData