require "TimedActions/ISBaseTimedAction"
ISLeadHorse = ISBaseTimedAction:derive("ISLeadHorse")

function ISLeadHorse:isValid()
    if self.horse and self.horse:isExistInTheWorld()
      and self.char and self.char:getSquare() then
        return true
    else
        return false
    end
end

function ISLeadHorse:waitToStart()
    return false
end

function ISLeadHorse:update()
    if self._lockDir then self.horse:setDir(self._lockDir) end
end

function ISLeadHorse:start()
    -- freeze horse and log horse facing direction
    if self.horse.getPathFindBehavior2 then self.horse:getPathFindBehavior2():reset() end
    if self.horse.getBehavior then self.horse:getBehavior():setBlockMovement(true) end
    self.horse:stopAllMovementNow()
    self._lockDir = self.horse:getDir()
    self._canceled = false
    self.char:setDir(self._lockDir)
    local function once()
        Events.OnTick.Remove(once)
        if self._canceled then return end
        if not (self.char and self.horse and self.horse:isExistInTheWorld()) then return end
        local hx, hy, hz = self.horse:getX(), self.horse:getY(), self.horse:getZ()
        self.char:setX(hx); self.char:setY(hy); self.char:setZ(hz)
        self.char:setDir(self._lockDir)
    end
    Events.OnTick.Add(once)

    self:setActionAnim("Bob_Mount_Bareback")
    if self.horse.playBreedSound then
        self.sound = self.horse:playBreedSound("pick_up")
    end
    self.char:setVariable("MountingHorse", true)
end

function ISLeadHorse:stop()
    if self.sound then self.char:stopOrTriggerSound(self.sound) end
    self._canceled = true
    if self.horse.getBehavior then self.horse:getBehavior():setBlockMovement(false) end
    if self.onCanceled then pcall(self.onCanceled, self) end
    self.char:setVariable("MountingHorse", false)
    ISBaseTimedAction.stop(self)
end

function ISLeadHorse:perform()
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

    self.char:setVariable("RidingHorse", true)
    if self.onMounted then pcall(self.onMounted, self) end
    ISBaseTimedAction.perform(self)
end

function ISLeadHorse:getDuration()
    if self.char:isTimedActionInstant() then return 1 end
    return 30
end

function ISLeadHorse:new(character, horse)
    local o = ISBaseTimedAction.new(self, character)
    o.char = character
    o.horse = horse
    o.stopOnWalk = true
    o.stopOnRun  = true
    o.maxTime = 140
    return o
end

return ISLeadHorse
