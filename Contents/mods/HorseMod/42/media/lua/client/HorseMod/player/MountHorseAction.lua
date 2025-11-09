require("TimedActions/ISBaseTimedAction")

local HorseRiding = require("HorseMod/Riding")


---@namespace HorseMod


---@class MountHorseAction : ISBaseTimedAction
---
---@field sound integer
---
---@field pair MountPair
---
---@field horse IsoAnimal
---
---@field side "left" | "right"
---
---@field saddle InventoryItem | nil
---
---@field lockDir IsoDirections
local MountHorseAction = ISBaseTimedAction:derive("MountHorseAction")


---@return boolean
function MountHorseAction:isValid()
    if 
        self.horse and self.horse:isExistInTheWorld()
        and self.character and self.character:getSquare()
    then
        return true
    else
        return false
    end
end


function MountHorseAction:update()
    assert(self.lockDir ~= nil)
    self.horse:setDir(self.lockDir)
    self.character:setDir(self.lockDir)

    if self.character:getVariableBoolean("MountFinished") == true then
        self.character:setVariable("MountFinished", false)
        self:forceComplete()
    end
end


function MountHorseAction:start()
    -- freeze horse and log horse facing direction
    self.horse:getPathFindBehavior2():reset()
    self.horse:getBehavior():setBlockMovement(true)
    self.horse:stopAllMovementNow()

    self.lockDir = self.horse:getDir()
    self.character:setDir(self.lockDir)

    self.character:setVariable("MountingHorse", true)
    self.character:setVariable("MountFinished", false)

    if self.side == "right" then
        if self.saddle then
            self:setActionAnim("Bob_Mount_Saddle_Right")
        else
            self:setActionAnim("Bob_Mount_Bareback_Right")
        end
    end

    if self.side == "left" then
        if self.saddle then
            self:setActionAnim("Bob_Mount_Saddle_Left")
        else
            self:setActionAnim("Bob_Mount_Bareback_Left")
        end
    end

    self.sound = self.horse:playBreedSound("pick_up")
end


function MountHorseAction:stop()
    self.character:stopOrTriggerSound(self.sound)

    self.horse:getBehavior():setBlockMovement(false)

    self.pair:setAnimationVariable("RidingHorse", false)
    self.character:setVariable("MountingHorse", false)
    self.character:setVariable("isTurningLeft", false)
    self.character:setVariable("isTurningRight", false)
    self.character:setTurnDelta(1)

    self.character:setVariable("MountingHorse", false)

    ISBaseTimedAction.stop(self)
end


function MountHorseAction:perform()
    self.character:stopOrTriggerSound(self.sound)

    HorseRiding.createMountFromPair(self.pair)

    ISBaseTimedAction.perform(self)
end


---@param pair MountPair
---@param side "left" | "right"
---@param saddle InventoryItem | nil
---@return self
---@nodiscard
function MountHorseAction:new(pair, side, saddle)
    ---@type MountHorseAction
    local o = ISBaseTimedAction.new(self, pair.rider)
    o.pair = pair
    o.horse = pair.mount
    o.side = side
    o.saddle = saddle
    o.stopOnWalk = true
    o.stopOnRun  = true

    o.maxTime = -1
    if o.character:isTimedActionInstant() then
        o.maxTime = 1
    end

    return o
end


return MountHorseAction