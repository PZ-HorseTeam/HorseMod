if isClient() then
    return
end

---@namespace HorseMod

local HorseUtils = require("HorseMod/Utils")
local commands = require("HorseMod/networking/commands")
local soundcommands = require("HorseMod/networking/soundcommands")


---Broadcast death sound so every client hears it
---@param character IsoGameCharacter
local function onCharacterDeath(character)
    if not isServer() then
        return
    end
    if not character:isAnimal() or not HorseUtils.isHorse(character) then
        return
    end
    ---@cast character IsoAnimal

    soundcommands.HorseSoundOneShot:send(nil--[[@as IsoPlayer?]], {
        animal = commands.getAnimalId(character),
        sound = "HorseDeath",
    })
end

Events.OnCharacterDeath.Add(onCharacterDeath)
