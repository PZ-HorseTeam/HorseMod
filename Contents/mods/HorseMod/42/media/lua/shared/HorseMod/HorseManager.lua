local HorseUtils = require("HorseMod/Utils")
local Event = require("HorseMod/Event")

---@namespace HorseMod


---@class System
local __System = {}

---@param horses IsoAnimal[]
---@param delta number
function __System:update(horses, delta) end


local HorseManager = {}

---@type IsoAnimal[]
HorseManager.horses = table.newarray()

---@type System[]
HorseManager.systems = table.newarray()

HorseManager.onHorseAdded = Event.new() ---@as Event<IsoAnimal>

HorseManager.onHorseRemoved = Event.new() ---@as Event<IsoAnimal>


function HorseManager.releaseRemovedHorses()
    for i = #HorseManager.horses, 1, -1 do
        local horse = HorseManager.horses[i]
        if not horse:isExistInTheWorld() then
            table.remove(HorseManager.horses, i)
            HorseManager.onHorseRemoved:trigger(horse)
        end
    end
end


---@param horse IsoAnimal
local function initialiseHorse(horse)
    horse:setVariable("isHorse", true)

    local speed = horse:getUsedGene("speed"):getCurrentValue()
    horse:setVariable("geneSpeed", speed)
    local strength = horse:getUsedGene("strength"):getCurrentValue()
    horse:setVariable("geneStrength", strength)
    local stamina = horse:getUsedGene("stamina"):getCurrentValue()
    horse:setVariable("geneStamina", stamina)
    local carry = horse:getUsedGene("carryWeight"):getCurrentValue()
    horse:setVariable("geneCarryWeight", carry)
end


-- we delay processing of newly spawned animals until the next tick
--  because their animal type isn't set when the event triggers
---@type IsoAnimal[]
local newAnimals = table.newarray()

Events.OnCreateLivingCharacter.Add(function(character, desc)
    if character:isAnimal() then
        ---@cast character IsoAnimal
        newAnimals[#newAnimals + 1] = character
    end
end)


local function processNewAnimals()
    for i = #newAnimals, 1, -1 do
        local animal = newAnimals[i]
        if HorseUtils.isHorse(animal) then
            initialiseHorse(animal)
            HorseManager.horses[#HorseManager.horses + 1] = animal
            HorseManager.onHorseAdded:trigger(animal)
        end
        newAnimals[i] = nil
    end
end


function HorseManager.update()
    processNewAnimals()
    HorseManager.releaseRemovedHorses()

    local delta = GameTime.getInstance():getTimeDelta()
    for i = 1, #HorseManager.systems do
        HorseManager.systems[i]:update(HorseManager.horses, delta)
    end
end

Events.OnTick.Add(HorseManager.update)


return HorseManager