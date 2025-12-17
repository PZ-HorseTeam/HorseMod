local HorseUtils = require("HorseMod/Utils")
local AnimationVariables = require("HorseMod/AnimationVariables")

local _originalFeedFromHandStart = ISFeedAnimalFromHand.start

function ISFeedAnimalFromHand:start()
    if HorseUtils.isHorse(self.animal) then
        self:setActionAnim("Bob_Horse_EatHand")
        self.animal:setVariable(AnimationVariables.EATING_HAND, true)
    end
    _originalFeedFromHandStart(self)
end

local _originalFeedFromHandUpdate = ISFeedAnimalFromHand.update

function ISFeedAnimalFromHand:update()
    if HorseUtils.isHorse(self.animal) then
        self.character:faceThisObject(self.animal)
        self.animal:faceThisObject(self.character)
    end
    _originalFeedFromHandUpdate(self)
end

local _originalFeedFromHandStop = ISFeedAnimalFromHand.stop

function ISFeedAnimalFromHand:stop()
    if HorseUtils.isHorse(self.animal) then
        self.animal:setVariable(AnimationVariables.EATING_HAND, false)
    end
    _originalFeedFromHandStop(self)
end

local _originalFeedFromHandPerform = ISFeedAnimalFromHand.perform

function ISFeedAnimalFromHand:perform()
    if HorseUtils.isHorse(self.animal) then
        self.animal:setVariable(AnimationVariables.EATING_HAND, false)
    end
    _originalFeedFromHandPerform(self)
end

local _originalFeedFromHandForceStop = ISFeedAnimalFromHand.forceStop

function ISFeedAnimalFromHand:forceStop()
    if HorseUtils.isHorse(self.animal) then
        self.animal:setVariable(AnimationVariables.EATING_HAND, false)
    end
    _originalFeedFromHandForceStop(self)
end

local _originalFeedFromHandGetDuration = ISFeedAnimalFromHand.getDuration

function ISFeedAnimalFromHand:getDuration()
	if HorseUtils.isHorse(self.animal) then
        return 240
    end
    return _originalFeedFromHandGetDuration(self)
end

local _originalFeedFromHandWaitToStart = ISFeedAnimalFromHand.waitToStart

function ISFeedAnimalFromHand:waitToStart()
    if HorseUtils.isHorse(self.animal) then
        self.character:faceThisObject(self.animal)
        self.animal:faceThisObject(self.character)
        return self.character:shouldBeTurning()
    end
    if _originalFeedFromHandWaitToStart then
        return _originalFeedFromHandWaitToStart(self)
    end
    return false
end