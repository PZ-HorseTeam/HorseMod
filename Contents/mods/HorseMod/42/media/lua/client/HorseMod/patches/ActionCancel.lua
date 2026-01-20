local UrgentDismountAction = require("HorseMod/TimedActions/UrgentDismountAction")

local original_isPlayerDoingActionThatCanBeCancelled = isPlayerDoingActionThatCanBeCancelled
function isPlayerDoingActionThatCanBeCancelled(player)
    local queue = ISTimedActionQueue.getTimedActionQueue(player)
    local current = queue.current
    if current and current.Type == UrgentDismountAction.Type then
        return false
    end
    return original_isPlayerDoingActionThatCanBeCancelled(player)
end