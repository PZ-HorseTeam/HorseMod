---@namespace HorseMod

---REQUIREMENTS
local HorseUtils = require("HorseMod/Utils")
local HorseManager = require("HorseMod/HorseManager")
local HorseModData = require("HorseMod/HorseModData")

local AnimalPickup = {}

AnimalPickup._originalComplete = ISPickupAnimal.complete
function ISPickupAnimal:complete()
    local animal = self.animal
    if animal and HorseUtils.isHorse(animal) then
        HorseModData.makeOrphan(animal)
        HorseManager.removeHorse(animal)
    end

    return AnimalPickup._originalComplete(self)
end

return AnimalPickup