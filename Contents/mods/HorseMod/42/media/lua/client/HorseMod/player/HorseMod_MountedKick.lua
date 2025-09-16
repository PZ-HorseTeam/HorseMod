local HorseRiding = require("HorseMod/shared/HorseMod_Riding")

local KICK_LOCK_SECONDS = 1.4
local KickState = {}

local function updateBannedAttacking(player)
    if not player then return end
    if player:getVariableBoolean("RidingHorse") then
        player:setBannedAttacking(true)
    else
        player:setBannedAttacking(false)
    end
end
Events.OnPlayerUpdate.Add(updateBannedAttacking)

local function updateKickCooldown(player)
    if not player then return end
    local id = player:getPlayerNum()
    local ks = KickState[id]
    if not ks or not ks.active then return end

    if not player:getVariableBoolean("RidingHorse") then
        player:setVariable("kickLeft", false)
        player:setVariable("kickRight", false)
        KickState[id] = nil
        return
    end

    ks.timeLeft = ks.timeLeft - GameTime.getInstance():getTimeDelta()
    if ks.timeLeft <= 0 then
        if ks.left  then player:setVariable("kickLeft",  false) end
        if ks.right then player:setVariable("kickRight", false) end
        player:setVariable("idleKicking", false)
        player:setVariable("moveKicking", false)
        KickState[id] = nil
    end
end
Events.OnPlayerUpdate.Add(updateKickCooldown)

local function horseKick(key)
    if key ~= Keyboard.KEY_SPACE then return end

    local player = getSpecificPlayer(0)
    if not player or not player:getVariableBoolean("RidingHorse") then return end

    local id = player:getPlayerNum()
    local ks = KickState[id]
    if ks and ks.active then
        return
    end

    local horse = HorseRiding.getMountedHorse and HorseRiding.getMountedHorse(player)
    if not horse then return end

    local cell = getCell()
    if not cell then return end

    -- find closest zombie in range
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

    local mountLeft  = horse:getAttachmentWorldPos("mountLeft")
    local mountRight = horse:getAttachmentWorldPos("mountRight")
    local zx, zy     = closest:getX(), closest:getY()
    local ldx, ldy   = zx - mountLeft:x(),  zy - mountLeft:y()
    local rdx, rdy   = zx - mountRight:x(), zy - mountRight:y()
    local leftDistSq  = ldx * ldx + ldy * ldy
    local rightDistSq = rdx * rdx + rdy * rdy

    local kickLeft = (leftDistSq < rightDistSq)
    player:setVariable("kickLeft",  kickLeft)
    player:setVariable("kickRight", not kickLeft)

    KickState[id] = { active = true, timeLeft = KICK_LOCK_SECONDS, left = kickLeft, right = not kickLeft }

    local zHp = closest:getHealth()
    if zHp > 0 then
        closest:setHealth(zHp * 0.99)
        if closest.knockDown then
            closest:knockDown(true)
        end
    end
end
Events.OnKeyPressed.Add(horseKick)

return {}
