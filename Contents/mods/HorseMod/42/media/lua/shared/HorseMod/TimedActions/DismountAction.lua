require("TimedActions/ISBaseTimedAction")

local AnimationVariable = require('HorseMod/definitions/AnimationVariable')
local Mounts = require("HorseMod/Mounts")
local AnimationEvent = require("HorseMod/definitions/AnimationEvent")
local MountedDirection = require("HorseMod/riding/MountedDirection")
local mountcommands = require("HorseMod/networking/mountcommands")
local commands = require("HorseMod/networking/commands")
local MountingUtility = require("HorseMod/mounting/MountingUtility")

local IS_SERVER = isServer()


---@namespace HorseMod


---@class DismountAction : ISBaseTimedAction
---
---@field character IsoPlayer
---
---@field animal IsoAnimal
---
---@field mount Mount
---
---@field mountPosition MountPosition
---
---@field hasSaddle boolean
---@field lockDirection IsoDirections
---
---Used to indicate whenever the action can be cancelled at some point.
---@field dynamicCancel boolean
local DismountAction = ISBaseTimedAction:derive("HorseMod_DismountAction")


---@return boolean
function DismountAction:isValid()
    local mountPosition = MountingUtility.getNearestMountPosition(self.character, self.animal)
    if not mountPosition then return false end

    return self.animal:isExistInTheWorld()
end


function DismountAction:update()
    -- keep the horse and player locked facing the stored direction
    local character = self.character
    local animal = self.animal

    MountedDirection.set(character, animal, self.lockDirection)
    animal:getPathFindBehavior2():reset()
end


function DismountAction:animEvent(event, parameter)
    if event == AnimationEvent.DISMOUNTING_COMPLETE then
        if IS_SERVER then
            ---@diagnostic disable-next-line: need-check-nil
            self.netAction:forceComplete()
        else
            self:forceComplete()
        end
    end
end


function DismountAction:start()
    local character = self.character
    self.lockDirection = character:getDir()
    character:setVariable(AnimationVariable.DISMOUNT_STARTED, true)
    character:setVariable(AnimationVariable.NO_CANCEL, false)

    -- start animation
    local actionAnim = ""
    if self.hasSaddle then
        actionAnim = "Bob_Dismount_Saddle_"
    else
        actionAnim = "Bob_Dismount_Bareback_"
    end

    actionAnim = actionAnim .. self.mountPosition.name
    self:setActionAnim(actionAnim)
end


---Returns the duration of the current animation in MS, as a workaround for animation events not working on the server.
---@return integer
function DismountAction:getAnimationDurationMS()
    if self.hasSaddle then
        return 3233
    end

    return 2066
end


function DismountAction:serverStart()
    ---@cast self.netAction -nil
    ---@diagnostic disable-next-line: param-type-mismatch
    emulateAnimEventOnce(self.netAction, self:getAnimationDurationMS(), AnimationEvent.DISMOUNTING_COMPLETE, nil)
    
    return true
end


function DismountAction:stop()
    self.character:setVariable(AnimationVariable.DISMOUNT_STARTED, false)
    ISBaseTimedAction.stop(self)
end


function DismountAction:complete()
    return true
end


function DismountAction:perform()
    if isServer() then
        -- server waits for the client's DismountRequest; Mounts.removeMount runs in the handler
    else
        -- Snap to the chosen mountLeft/mountRight attachment
        local mountPosition = MountingUtility.getNearestMountPosition(self.character, self.animal)
        if mountPosition then
            self.character:setX(mountPosition.x)
            self.character:setY(mountPosition.y)
            self.character:setZ(self.animal:getZ())
        end

        if isClient() then
            mountcommands.DismountRequest:send(
                self.character,
                {
                    animal = commands.getAnimalId(self.animal),
                    attachment = self.mountPosition.attachment,
                }
            )
        end

        Mounts.removeMount(self.character)
    end

    ISBaseTimedAction.perform(self)
end


function DismountAction:getDuration()
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
function DismountAction:new(character, animal, mountPosition, hasSaddle)
    ---@type DismountAction
    local o = ISBaseTimedAction.new(self, character)

    o.character = character
    o.animal = animal
    o.mountPosition = mountPosition
    o.hasSaddle = hasSaddle
    o.stopOnWalk = false
    o.stopOnRun = true
    o.stopOnAim = false

    o.maxTime = o:getDuration()
    o.useProgressBar = false
    o.dynamicCancel = true

    return o
end


_G[DismountAction.Type] = DismountAction


return DismountAction
