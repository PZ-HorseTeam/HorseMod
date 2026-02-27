---REQUIREMENTS
local Mounts = require("HorseMod/Mounts")

local ActionBlocker = require("HorseMod/patches/ActionBlocker")

--[[
This patch prevents players from performing certain timed actions while mounted on a horse.
]]
local ActionBlockerClient = {}

ActionBlockerClient.addAfter = ISTimedActionQueue.addAfter
function ISTimedActionQueue.addAfter(previousAction, action)
    if action and Mounts.hasMount(action.character) then
        if not ActionBlocker.validActions[action.Type] then
            return
        end
    end
    ActionBlockerClient.addAfter(previousAction, action)
end

ActionBlockerClient.add = ISTimedActionQueue.add
function ISTimedActionQueue.add(action)
    if not action then return end
    if action and Mounts.hasMount(action.character) then
        if not ActionBlocker.validActions[action.Type] then
            return
        end
    end
    ActionBlockerClient.add(action)
end

return ActionBlockerClient