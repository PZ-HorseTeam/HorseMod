require("TimedActions/ISBaseTimedAction")

local AnimationVariable = require('HorseMod/definitions/AnimationVariable')
local Mounts = require("HorseMod/Mounts")


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
---
---Used to indicate whenever the action can be cancelled at some point.
---@field dynamicCancel boolean
local DismountAction = ISBaseTimedAction:derive("HorseMod_DismountAction")


---@return boolean
function DismountAction:isValid()
    return self.animal:isExistInTheWorld()
end


function DismountAction:update()
    -- keep the horse and player locked facing the stored direction
    local character = self.character
    local animal = self.animal

    animal:setDirectionAngle(self.lockDir)
    animal:getPathFindBehavior2():reset()

    character:setDirectionAngle(self.lockDir)

    -- complete when dismount is finished
    if character:getVariableBoolean(AnimationVariable.DISMOUNT_FINISHED) == true then
        character:setVariable(AnimationVariable.DISMOUNT_FINISHED, false)
        self:forceComplete()
    end
end


function DismountAction:start()
    local character = self.character
    self.lockDir = self.animal:getDirectionAngle()
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


function DismountAction:stop()
    self.character:setVariable(AnimationVariable.DISMOUNT_STARTED, false)
    ISBaseTimedAction.stop(self)
end


function DismountAction:complete()
    -- TODO: this might take a bit to inform the client, so we should consider faking it in perform()
    Mounts.removeMount(self.character)
    return true
end


function DismountAction:perform()
    local mountPosition = self.mountPosition
    local attachmentPosition = self.animal:getAttachmentWorldPos(mountPosition.attachment)
    self.character:setX(attachmentPosition:x())
    self.character:setY(attachmentPosition:y())

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