local AnimationVariable = require('HorseMod/definitions/AnimationVariable')
local Mounts = require("HorseMod/Mounts")

---@class MountedAttack
---@field active boolean
---@field timeLeft number
---@field left boolean
---@field right boolean
---@type table<number, MountedAttack>
local MountedAttack = {}

MountedAttack.KICK_LOCK_SECONDS = 1.4


---@param player IsoPlayer
local function updateBannedAttacking(player)
    if not player then return end

    if player:getVariableBoolean(AnimationVariable.RIDING_HORSE) then
        player:setBannedAttacking(true)
    else
        player:setBannedAttacking(false)
    end
end

Events.OnPlayerUpdate.Add(updateBannedAttacking)


---@param player IsoPlayer
local function updateKickCooldown(player)
    if not player then return end

    local id = player:getPlayerNum()
    local ks = MountedAttack[id]
    if not ks or not ks.active then return end

    if not player:getVariableBoolean(AnimationVariable.RIDING_HORSE) then
        player:setVariable(AnimationVariable.KICK_LEFT, false)
        player:setVariable(AnimationVariable.KICK_RIGHT, false)
        MountedAttack[id] = nil
        return
    end

    ks.timeLeft = ks.timeLeft - GameTime.getInstance():getTimeDelta()
    if ks.timeLeft <= 0 then
        if ks.left then
            player:setVariable(AnimationVariable.KICK_LEFT, false)
        end

        if ks.right then
            player:setVariable(AnimationVariable.KICK_RIGHT, false)
        end

        player:setVariable(AnimationVariable.IDLE_KICKING, false)
        player:setVariable(AnimationVariable.MOVE_KICKING, false)
        MountedAttack[id] = nil
    end
end

Events.OnPlayerUpdate.Add(updateKickCooldown)


---@param key number
function MountedAttack.horseKick(key)
    if key ~= Keyboard.KEY_SPACE then return end

    local player = getSpecificPlayer(0)
    if not player or not player:getVariableBoolean(AnimationVariable.RIDING_HORSE) then return end

    local id = player:getPlayerNum()
    local ks = MountedAttack[id]
    if ks and ks.active then
        return
    end

    local horse = Mounts.getMount(player)
    if not horse then return end

    local cell = getCell()
    if not cell then return end

    local zombies = cell:getZombieList()
    local closest, closestDistSq
    local px, py = player:getX(), player:getY()
    local rangeSq = (1.5 * 1.5)
    for i = 0, zombies:size() - 1 do
        local z = zombies:get(i)
        local dx = z:getX() - px
        local dy = z:getY() - py
        local d2 = dx * dx + dy * dy
        if d2 < rangeSq and (not closestDistSq or d2 < closestDistSq) then
            closest = z
            closestDistSq = d2
        end
    end
    if not closest then return end

    local mountLeft = horse:getAttachmentWorldPos("mountLeft")
    local mountRight = horse:getAttachmentWorldPos("mountRight")
    local zx, zy = closest:getX(), closest:getY()
    local ldx, ldy = zx - mountLeft:x(), zy - mountLeft:y()
    local rdx, rdy = zx - mountRight:x(), zy - mountRight:y()
    local leftDistSq = ldx * ldx + ldy * ldy
    local rightDistSq = rdx * rdx + rdy * rdy

    local kickLeft = (leftDistSq < rightDistSq)
    player:setVariable(AnimationVariable.KICK_LEFT, kickLeft)
    player:setVariable(AnimationVariable.KICK_RIGHT, not kickLeft)

    MountedAttack[id] = {
        active = true,
        timeLeft = MountedAttack.KICK_LOCK_SECONDS,
        left = kickLeft,
        right = not kickLeft,
    }

    local zHp = closest:getHealth()
    if zHp > 0 and closest.knockDown then
        closest:knockDown(true)
    end
end

Events.OnKeyPressed.Add(MountedAttack.horseKick)


return MountedAttack
