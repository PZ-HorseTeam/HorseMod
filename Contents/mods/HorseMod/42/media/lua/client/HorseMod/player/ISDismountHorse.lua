require "TimedActions/ISBaseTimedAction"

ISDismountHorse = ISBaseTimedAction:derive("ISDismountHorse")

function ISDismountHorse:isValid()
    return self.horse and self.horse:isExistInTheWorld()
           and self.char and self.char:getAttachedAnimals()
           and self.char:getAttachedAnimals():contains(self.horse)
end

function ISDismountHorse:waitToStart() return false end

function ISDismountHorse:update()
    -- keep the horse locked facing the stored direction
    if self._lockDir then self.horse:setDir(self._lockDir) end
    -- keep the player facing the horse's head (same dir as horse)
    if self._lockDir then self.char:setDir(self._lockDir) end
        if self.char:getVariableBoolean("DismountFinished") == true then
        self.char:setVariable("DismountFinished", false)
        self:forceComplete()
    end
end

function ISDismountHorse:start()
    if self.horse.getPathFindBehavior2 then self.horse:getPathFindBehavior2():reset() end
    if self.horse.getBehavior then self.horse:getBehavior():setBlockMovement(true) end
    if self.horse.stopAllMovementNow then self.horse:stopAllMovementNow() end

    self._lockDir  = self.horse:getDir()
    self._canceled = false

    self.char:setDir(self._lockDir)

    if self.side == "right" then
        if self.saddle then self:setActionAnim("Bob_Dismount_Saddle_Right")
        else self:setActionAnim("Bob_Dismount_Bareback_Right") end
    else
        if self.saddle then self:setActionAnim("Bob_Dismount_Saddle_Left")
        else self:setActionAnim("Bob_Dismount_Bareback_Left") end
    end
end

function ISDismountHorse:stop()
    self._canceled = true
    if self.horse.getBehavior then self.horse:getBehavior():setBlockMovement(false) end
    self.char:setVariable("RidingHorse", true)
    ISBaseTimedAction.stop(self)
end

function ISDismountHorse:perform()
    local attached = self.char:getAttachedAnimals()
    if attached and attached:contains(self.horse) then
        attached:remove(self.horse)
    end
    if self.horse.getData then
        self.horse:getData():setAttachedPlayer(nil)
    end

    local wx, wy, wz = self.landX, self.landY, self.landZ
    if wx and wy then
        self.char:setX(wx); self.char:setY(wy)
        if wz then self.char:setZ(wz) end
    end
    if self._lockDir then
        self.char:setDir(self._lockDir)
    end

    if self.horse.getBehavior then self.horse:getBehavior():setBlockMovement(false) end
    if self.horse.getPathFindBehavior2 then self.horse:getPathFindBehavior2():reset() end
    if self.horse.setVariable then
        self.horse:setVariable("bPathfind", false)
        self.horse:setVariable("animalWalking", false)
        self.horse:setVariable("animalRunning", false)
        self.horse:setVariable("HorseTrot", false)
        self.horse:setVariable("RidingHorse", false)
    end

    self.char:setVariable("RidingHorse", false)
    self.char:setVariable("MountingHorse", false)
    self.char:setVariable("isTurningLeft", false)
    self.char:setVariable("isTurningRight", false)

    if self.onComplete then
        pcall(self.onComplete)
    end

    ISBaseTimedAction.perform(self)
end

function ISDismountHorse:getDuration()
    if self.char:isTimedActionInstant() then return 1 end
    return self.maxTime or 200
end

function ISDismountHorse:new(character, horse, side, saddleItem, landX, landY, landZ)
    local o = ISBaseTimedAction.new(self, character)
    o.char     = character
    o.horse    = horse
    o.side     = side or "right"
    o.saddle   = saddleItem ~= nil
    o.landX    = landX
    o.landY    = landY
    o.landZ    = landZ
    o.maxTime  = -1
    o.stopOnWalk = true
    o.stopOnRun  = true
    return o
end

return ISDismountHorse
