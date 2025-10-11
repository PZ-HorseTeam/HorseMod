require "TimedActions/ISBaseTimedAction"
ISMountHorse = ISBaseTimedAction:derive("ISMountHorse")

function ISMountHorse:isValid()
    if self.horse and self.horse:isExistInTheWorld()
      and self.char and self.char:getSquare() then
        return true
    else
        return false
    end
end

function ISMountHorse:waitToStart()
    return false
end

function ISMountHorse:update()
    if self._lockDir then self.horse:setDir(self._lockDir) end
    if self.char:getVariableBoolean("MountFinished") == true then
        self.char:setVariable("MountFinished", false)
        self:forceComplete()
    end
end

function ISMountHorse:start()
    -- freeze horse and log horse facing direction
    if self.horse.getPathFindBehavior2 then self.horse:getPathFindBehavior2():reset() end
    if self.horse.getBehavior then self.horse:getBehavior():setBlockMovement(true) end
    self.horse:stopAllMovementNow()
    self._lockDir = self.horse:getDir()
    self._canceled = false
    self.char:setVariable("MountingHorse", true)
    self.char:setVariable("MountFinished", false)
    if self.side == "right" then
        if self.saddle then self:setActionAnim("Bob_Mount_Saddle_Right")
        else self:setActionAnim("Bob_Mount_Bareback_Right") end
    end
    if self.side == "left" then
        if self.saddle then self:setActionAnim("Bob_Mount_Saddle_Left")
        else self:setActionAnim("Bob_Mount_Bareback_Left") end
    end
    if self.horse.playBreedSound then
        self.sound = self.horse:playBreedSound("pick_up")
    end
end

function ISMountHorse:stop()
    if self.sound then self.char:stopOrTriggerSound(self.sound) end
    self._canceled = true
    if self.horse.getBehavior then self.horse:getBehavior():setBlockMovement(false) end
    if self.onCanceled then pcall(self.onCanceled, self) end
    self.char:setVariable("MountingHorse", false)
    ISBaseTimedAction.stop(self)
end

function ISMountHorse:perform()
    if self.sound then self.char:stopOrTriggerSound(self.sound) end

    self.char:getAttachedAnimals():add(self.horse)
    self.horse:getData():setAttachedPlayer(self.char)
    self.horse:setWild(false)
    self.horse:setVariable("isHorse", true)

    if self.horse.getPathFindBehavior2 then self.horse:getPathFindBehavior2():reset() end
    if self.horse.getBehavior then self.horse:getBehavior():setBlockMovement(true) end
    if self.horse.setVariable then
        self.horse:setVariable("bPathfind", false)
        self.horse:setVariable("animalWalking", false)
        self.horse:setVariable("animalRunning", false)
    end
    if self.horse.stopAllMovementNow then self.horse:stopAllMovementNow() end

    local geneSpeed = self.horse:getUsedGene("speed"):getCurrentValue()

    self.char:setVariable("RidingHorse", true)
    self.horse:setVariable("RidingHorse", true)
    self.horse:setVariable("HorseTrot", false)
    self.char:setVariable("HorseTrot", false)
    self.char:setAllowRun(false)
    self.char:setAllowSprint(false)
    self.char:setVariable("isTurningLeft", false)
    self.char:setVariable("isTurningRight", false)
    self.char:setVariable("geneSpeed", geneSpeed)
    if self.onMounted then pcall(self.onMounted, self) end
    ISBaseTimedAction.perform(self)
end

function ISMountHorse:getDuration()
    if self.char:isTimedActionInstant() then return 1 end
    return 30
end

function ISMountHorse:new(character, horse, side, saddle)
    local o = ISBaseTimedAction.new(self, character)
    o.char = character
    o.horse = horse
    o.side = side
    o.saddle = saddle
    o.stopOnWalk = true
    o.stopOnRun  = true
    o.maxTime = -1
    return o
end

return ISMountHorse
