--[[
This file hooks to the vanilla action to patch for the horse
]]



---REQUIREMENTS
local HorseUtils = require("HorseMod/Utils")
local AnimationVariable = require('HorseMod/definitions/AnimationVariable')


local _originalFeedFromHandStart = ISFeedAnimalFromHand.start

function ISFeedAnimalFromHand:start()
    if HorseUtils.isHorse(self.animal) then
        if self.character:getVariableBoolean(AnimationVariable.RIDING_HORSE) then
            self:setActionAnim("Bob_Horse_EatHandMounted")
            self.animal:setVariable("eatingAnim", "eat2")
        else
            self:setActionAnim("Bob_Horse_EatHand")
            self.animal:setVariable("eatingAnim", "eat1")
        end
        self.animal:setVariable(AnimationVariable.EATING_HAND, true)
    end
    return _originalFeedFromHandStart(self)
end


local _originalFeedFromHandUpdate = ISFeedAnimalFromHand.update

function ISFeedAnimalFromHand:update()
    if HorseUtils.isHorse(self.animal) then
        if self.character:getVariableBoolean(AnimationVariable.RIDING_HORSE) then
            return
        end
    end
    return _originalFeedFromHandUpdate(self)
end


local _originalFeedFromHandStop = ISFeedAnimalFromHand.stop

function ISFeedAnimalFromHand:stop()
    if HorseUtils.isHorse(self.animal) then
        self.animal:clearVariable("eatingAnim")
        self.animal:setVariable(AnimationVariable.EATING_HAND, false)
    end
    return _originalFeedFromHandStop(self)
end


local _originalFeedFromHandPerform = ISFeedAnimalFromHand.perform

function ISFeedAnimalFromHand:perform()
    if HorseUtils.isHorse(self.animal) then
        self.animal:clearVariable("eatingAnim")
        self.animal:setVariable(AnimationVariable.EATING_HAND, false)
    end
    return _originalFeedFromHandPerform(self)
end


local _originalFeedFromHandForceStop = ISFeedAnimalFromHand.forceStop

function ISFeedAnimalFromHand:forceStop()
    if HorseUtils.isHorse(self.animal) then
        self.animal:clearVariable("eatingAnim")
    end
    return _originalFeedFromHandForceStop(self)
end


local _originalFeedFromHandGetDuration = ISFeedAnimalFromHand.getDuration

function ISFeedAnimalFromHand:getDuration()
	if HorseUtils.isHorse(self.animal) then
        return 260
    end
    return _originalFeedFromHandGetDuration(self)
end


local _originalFeedFromHandWaitToStart = ISFeedAnimalFromHand.waitToStart

function ISFeedAnimalFromHand:waitToStart()
    if HorseUtils.isHorse(self.animal) then
        if self.character:getVariableBoolean(AnimationVariable.RIDING_HORSE) then
            return false
        end
    end
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