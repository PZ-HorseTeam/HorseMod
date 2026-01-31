---@namespace HorseMod

local AnimationEvent = require("HorseMod/definitions/AnimationEvent")

---@class BaseGearAction : ISBaseTimedAction, umbrella.NetworkedTimedAction
---@field horse IsoAnimal
local BaseGearAction = ISBaseTimedAction:derive("HorseMod_HorseEquipGear")

function BaseGearAction:waitToStart()
    self.character:faceThisObject(self.horse)
    return self.character:shouldBeTurning()
end

---@return boolean
function BaseGearAction:isValid()
    return self.horse:isExistInTheWorld()
end

function BaseGearAction:serverStart()
    if self.maxTime == -1 then
        ---@diagnostic disable-next-line: param-type-mismatch
        emulateAnimEventOnce(self.netAction, 1000, AnimationEvent.EQUIP_FINISHED, nil)
    end

    return true
end

function BaseGearAction:update()
    self.character:faceThisObject(self.horse)
    self.horse:getPathFindBehavior2():reset()
end


function BaseGearAction:animEvent(event, parameter)
    if event == AnimationEvent.EQUIP_FINISHED then
        if isServer() then
            ---@diagnostic disable-next-line: need-check-nil
            self.netAction:forceComplete()
        else
            self:forceComplete()
        end
    end
end

---@param character IsoGameCharacter
---@param horse IsoAnimal
---@return BaseGearAction
---@nodiscard
function BaseGearAction:new(character, horse)
    local o = ISBaseTimedAction.new(self, character) ---@as BaseGearAction

    o.horse = horse

    -- default attachment actions
    o.stopOnWalk = true
    o.stopOnRun  = true
    o.stopOnAim  = true

    return o
end

return BaseGearAction