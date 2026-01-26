require("TimedActions/ISBaseTimedAction")

local MountPair = require("HorseMod/MountPair")
local AnimationVariable = require('HorseMod/definitions/AnimationVariable')
local Mounts = require("HorseMod/Mounts")
local MountingUtility = require("HorseMod/mounting/MountingUtility")
local AnimationEvent = require("HorseMod/definitions/AnimationEvent")

local IS_SERVER = isServer()

---@namespace HorseMod


---@class MountAction : ISBaseTimedAction, umbrella.NetworkedTimedAction
---
---@field character IsoPlayer
---
---@field animal IsoAnimal
---
---@field mountPosition MountPosition
---
---@field hasSaddle boolean
---
---@field lockDir number
---
---Used to indicate whenever the action can be cancelled at some point.
---@field dynamicCancel boolean
local MountAction = ISBaseTimedAction:derive("HorseMod_MountAction")



function MountAction:isValid()
    if self.animal:isExistInTheWorld()
        and self.character:getSquare() then
        
        -- verify the player can still mount the horse
        if MountingUtility.canMountHorse(self.character, self.animal) then
            return true
        end
        return false
    else
        return false
    end
end

function MountAction:waitToStart()
    -- self.character:faceThisObject(self.mount)
    self.lockDir = self.animal:getDirectionAngle()
    self.character:setDirectionAngle(self.lockDir)
	return self.character:shouldBeTurning()
end


function MountAction:update()
    -- fix the mount and rider to look in the same direction for animation alignment
    local character = self.character
    local animal = self.animal
    
    animal:setDirectionAngle(self.lockDir)
    animal:getPathFindBehavior2():reset()
    
    character:setDirectionAngle(self.lockDir)
end


function MountAction:animEvent(event, parameter)
    if event == AnimationEvent.MOUNTING_COMPLETE then
        if IS_SERVER then
            ---@diagnostic disable-next-line: need-check-nil
            self.netAction:forceComplete()
        else
            self:forceComplete()
        end
    end
end


function MountAction:start()
    local character = self.character
    character:setVariable(AnimationVariable.MOUNTING_HORSE, true)
    character:setVariable(AnimationVariable.NO_CANCEL, false)

    -- start animation
    local actionAnim = ""
    if self.hasSaddle then
        actionAnim = "Bob_Mount_Saddle_"
    else
        actionAnim = "Bob_Mount_Bareback_"
    end

    actionAnim = actionAnim .. self.mountPosition.name
    self:setActionAnim(actionAnim)
end


function MountAction:serverStart()
    ---@cast self.netAction -nil
    ---@diagnostic disable-next-line: param-type-mismatch
    emulateAnimEventOnce(self.netAction, 2500, AnimationEvent.MOUNTING_COMPLETE, nil)
    return true
end


function MountAction:stop()
    local character = self.character
    local pair = MountPair.new(character, self.animal)
    pair:setAnimationVariable(AnimationVariable.RIDING_HORSE, false)
    character:setVariable(AnimationVariable.MOUNTING_HORSE, false)

    ISBaseTimedAction.stop(self)
end


function MountAction:complete()
    Mounts.addMount(self.character, self.animal)
    return true
end


function MountAction:perform()
    -- HACK: we can't require this at file load because it is in the client dir
    local HorseSounds = require("HorseMod/HorseSounds")
    HorseSounds.playSound(self.animal, HorseSounds.Sound.MOUNT)

    ISBaseTimedAction.perform(self)
end


function MountAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end

    return -1
end


---@param character IsoPlayer
---@param animal IsoAnimal
---@param mountPosition MountPosition
---@param hasSaddle boolean
---@return self
---@nodiscard
function MountAction:new(character, animal, mountPosition, hasSaddle)
    ---@type MountAction
    local o = ISBaseTimedAction.new(self, character)

    o.character = character
    o.animal = animal
    o.mountPosition = mountPosition
    o.hasSaddle = hasSaddle
    o.stopOnWalk = false
    o.stopOnRun  = true
    o.stopOnAim = false

    o.maxTime = o:getDuration()
    o.useProgressBar = false
    o.dynamicCancel = true

    return o
end


_G[MountAction.Type] = MountAction


return MountAction