local HorseUtils = require("HorseMod/Utils")
local Event = require("HorseMod/Event")

---@namespace HorseMod


---@class System
local __System = {}

---@param horses IsoAnimal[]
---@param delta number
function __System:update(horses, delta) end


local HorseManager = {
    ---Table holding all the available horses in the player cell.
    ---@type IsoAnimal[]
    horses = table.newarray(),

    ---@type table<IsoAnimal, true?>
    _detected_horses = {},

    ---Systems for horses that are triggered for them every ticks.
    ---@type System[]
    systems = table.newarray(),
}

---Triggers when a horse gets loaded in.
HorseManager.onHorseAdded = Event.new() ---@as Event<IsoAnimal>

---Triggers when a horse gets unloaded.
HorseManager.onHorseRemoved = Event.new() ---@as Event<IsoAnimal>





function HorseManager.releaseRemovedHorses()
    for i = #HorseManager.horses, 1, -1 do
        local horse = HorseManager.horses[i]
        if not horse:isExistInTheWorld() or horse:isDead() then
            table.remove(HorseManager.horses, i)
            HorseManager.onHorseRemoved:trigger(horse)
            HorseManager._detected_horses[horse] = nil
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

---Utility function to find a horse by its animal ID.
---@param animalID number
---@return IsoAnimal?
HorseManager.findHorseByID = function(animalID)
    local horses = HorseManager.horses
    for i = 1, #horses do
        local horse = horses[i]
        if horse:getAnimalID() == animalID then
            return horse
        end
    end
    return nil
end


---Detect newly created horses par parsing the moving objects array list of the player cell 

local UPDATE_RATE = 8
local TICK_AMOUNT = 0

---Retrieve newly loaded horses in the world.
---@TODO find a better method of doing this, less costly
HorseManager.retrieveNewHorses = function()
    -- retrieve IsoMovingObjects
    local isoMovingObjects = getCell():getObjectList()

    -- check UPDATE_RATE-th IsoMovingObjects per tick
    local size = isoMovingObjects:size()
    local update_rate = UPDATE_RATE < size and UPDATE_RATE or size
    if update_rate == 0 then return end

    -- update to next tick amount offset to parse next selection of the list
    TICK_AMOUNT = TICK_AMOUNT < update_rate - 1 and TICK_AMOUNT + 1 or 0

    -- iterate every update_rate-th entries
    for i = TICK_AMOUNT, size - 1, update_rate do
        local isoMovingObject = isoMovingObjects:get(i)

        -- verify is an animal and horse and not already checked and not dead
        if instanceof(isoMovingObject, "IsoAnimal") 
            and HorseUtils.isHorse(isoMovingObject) 
            and not HorseManager._detected_horses[isoMovingObject]
            and not isoMovingObject:isDead() then
            
            initialiseHorse(isoMovingObject)
            HorseManager.horses[#HorseManager.horses + 1] = isoMovingObject
            HorseManager.onHorseAdded:trigger(isoMovingObject)

            HorseManager._detected_horses[isoMovingObject] = true
        end
    end
end

Events.OnTick.Add(HorseManager.retrieveNewHorses)

---Sends
function HorseManager.update()
    -- processNewAnimals()
    HorseManager.releaseRemovedHorses()

    local delta = GameTime.getInstance():getTimeDelta()
    for i = 1, #HorseManager.systems do
        HorseManager.systems[i]:update(HorseManager.horses, delta)
    end
end

Events.OnTick.Add(HorseManager.update)


return HorseManager