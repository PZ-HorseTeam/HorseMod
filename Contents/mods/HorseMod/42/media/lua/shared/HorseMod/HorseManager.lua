---REQUIREMENTS
local HorseUtils = require("HorseMod/Utils")
local Event = require("HorseMod/Event")
local AnimationVariable = require('HorseMod/definitions/AnimationVariable')

---@namespace HorseMod


--- A system is a module to process behavior or logic for horses.
---@class System
local __System = {}

---@param horses IsoAnimal[]
---@param delta number
function __System:update(horses, delta) end

---Used to manage horses presence in the world, whenever they are loaded / unloaded.
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
HorseManager.onHorseAdded = Event.new--[[@<IsoAnimal>]]()

---Triggers when a horse gets unloaded.
HorseManager.onHorseRemoved = Event.new--[[@<IsoAnimal>]]()

---Triggers before a horse manager update.
HorseManager.preUpdate = Event.new()

function HorseManager.removeHorse(horse, i)
    if i then
        table.remove(HorseManager.horses, i)
    else
        for i = #HorseManager.horses, 1, -1 do
            if HorseManager.horses[i] == horse then
                table.remove(HorseManager.horses, i)
                break
            end
        end
    end
    HorseManager.onHorseRemoved:trigger(horse)
    HorseManager._detected_horses[horse] = nil
end

function HorseManager.releaseRemovedHorses()
    for i = #HorseManager.horses, 1, -1 do
        local horse = HorseManager.horses[i]
        if not horse:isExistInTheWorld() or horse:isDead() then
            HorseManager.removeHorse(horse, i)
        end
    end
end


---@param horse IsoAnimal
local function initialiseHorse(horse)
    horse:setVariable(AnimationVariable.IS_HORSE, true)

    local speed = horse:getUsedGene("speed"):getCurrentValue()
    horse:setVariable(AnimationVariable.GENE_SPEED, speed)
    local strength = horse:getUsedGene("strength"):getCurrentValue()
    horse:setVariable(AnimationVariable.GENE_STRENGTH, strength)
    local stamina = horse:getUsedGene("stamina"):getCurrentValue()
    horse:setVariable(AnimationVariable.GENE_STAMINA, stamina)
    local carry = horse:getUsedGene("carryWeight"):getCurrentValue()
    horse:setVariable(AnimationVariable.GENE_CARRYWEIGHT, carry)

    -- this is used to make sure the animal gets its size properly set
    -- on the new IsoAnimal instance created when attaching to a butcher hook
    -- which is done in ButcheringUtil.createAnimalForHook
    -- and in Java side when reloading the area/save
    horse:getModData()['animalSize'] = horse:getAnimalSize()
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


---Detect newly created horses by parsing the moving objects array list of the player cell 

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
    for i = TICK_AMOUNT, size - 1, update_rate do repeat
        local isoMovingObject = isoMovingObjects:get(i)

        -- verify is an animal 
        if not instanceof(isoMovingObject, "IsoAnimal") then break end
        ---@cast isoMovingObject IsoAnimal 

        -- verify is a horse and not already checked and not dead
        if HorseUtils.isHorse(isoMovingObject) 
            and not HorseManager._detected_horses[isoMovingObject] then
            
            -- initialise horse
            initialiseHorse(isoMovingObject)
            
            -- trigger horse init event
            HorseManager.onHorseAdded:trigger(isoMovingObject)

            -- add to detected horses
            HorseManager.horses[#HorseManager.horses + 1] = isoMovingObject
            HorseManager._detected_horses[isoMovingObject] = true
        end
    until true end
end

-- Events.OnTick.Add(HorseManager.retrieveNewHorses)

---Sends
function HorseManager.update()
    HorseManager.retrieveNewHorses()
    HorseManager.releaseRemovedHorses()

    HorseManager.preUpdate:trigger()

    local delta = GameTime.getInstance():getTimeDelta()
    for i = 1, #HorseManager.systems do
        HorseManager.systems[i]:update(HorseManager.horses, delta)
    end
end

Events.OnTick.Add(HorseManager.update)


return HorseManager