local HorseUtils = require("HorseMod/Utils")
local AnimationVariable = require('HorseMod/definitions/AnimationVariable')


local _originalPetAnimalStart = ISPetAnimal.start

function ISPetAnimal:start()
    if HorseUtils.isHorse(self.animal) then
        if not HorseUtils.isAdult(self.animal) then
            self.character:setVariable("pettingFilly", true)
        end
        if self.character:getVariableBoolean(AnimationVariable.RIDING_HORSE) then
            self.character:setVariable("pettingMounted", true)
        end
    end
    return _originalPetAnimalStart(self)
end


local _originalPetAnimalisValid = ISPetAnimal.isValid

function ISPetAnimal:isValid()
    if HorseUtils.isHorse(self.animal) then
        if self.character:getVariableBoolean(AnimationVariable.RIDING_HORSE) then
            return true
        end
    end
    return _originalPetAnimalisValid(self)
end


local _originalPetAnimalwaitToStart = ISPetAnimal.waitToStart

function ISPetAnimal:waitToStart()
    if HorseUtils.isHorse(self.animal) then
        if self.character:getVariableBoolean(AnimationVariable.RIDING_HORSE) then
            return false
        end
    end
    return _originalPetAnimalwaitToStart(self)
end


local _originalPetAnimalUpdate = ISPetAnimal.update

function ISPetAnimal:update()
    if HorseUtils.isHorse(self.animal) then
        if self.character:getVariableBoolean(AnimationVariable.RIDING_HORSE) then
            return
        end
    end

	return _originalPetAnimalUpdate(self)
end


local _originalPetAnimalNew = ISPetAnimal.new

function ISPetAnimal:new(character, animal)
    local o = _originalPetAnimalNew(self, character, animal)
    if HorseUtils.isHorse(animal) then
        if character:getVariableBoolean(AnimationVariable.RIDING_HORSE) then
            o.stopOnWalk = false
            o.stopOnRun = false
        end
    end
    return o
end
