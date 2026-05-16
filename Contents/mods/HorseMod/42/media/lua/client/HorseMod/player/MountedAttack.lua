local AnimationVariable = require('HorseMod/definitions/AnimationVariable')
local Mounts = require("HorseMod/Mounts")
local commands = require("HorseMod/networking/commands")
local mountcommands = require("HorseMod/networking/mountcommands")

local IS_CLIENT = isClient()
local IS_SERVER = isServer()

---@class KickCooldown
---@field active boolean
---@field timeLeft number
---@field left boolean
---@field right boolean

---@type table<IsoPlayer, KickCooldown>
local cooldowns = {}

local MountedAttack = {}

MountedAttack.KICK_LOCK_SECONDS = 1.4


---safe emptiness check.
---@param t table
---@return boolean
---@nodiscard
local function isEmpty(t)
    for _ in pairs(t) do
        return false
    end
    return true
end


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


local function tickKickCooldowns()
    if isEmpty(cooldowns) then return end

    local dt = GameTime.getInstance():getTimeDelta()

    for player, ks in pairs(cooldowns) do
        if not player or not player:getVariableBoolean(AnimationVariable.RIDING_HORSE) then
            if player then
                player:setVariable(AnimationVariable.KICK_LEFT, false)
                player:setVariable(AnimationVariable.KICK_RIGHT, false)
                player:setVariable(AnimationVariable.IDLE_KICKING, false)
                player:setVariable(AnimationVariable.MOVE_KICKING, false)
            end
            cooldowns[player] = nil
        else
            ks.timeLeft = ks.timeLeft - dt
            if ks.timeLeft <= 0 then
                if ks.left then
                    player:setVariable(AnimationVariable.KICK_LEFT, false)
                end
                if ks.right then
                    player:setVariable(AnimationVariable.KICK_RIGHT, false)
                end
                player:setVariable(AnimationVariable.IDLE_KICKING, false)
                player:setVariable(AnimationVariable.MOVE_KICKING, false)
                cooldowns[player] = nil
            end
        end
    end
end

Events.OnTick.Add(tickKickCooldowns)


---@param player IsoPlayer
---@param kickLeft boolean
local function armKickCooldown(player, kickLeft)
    cooldowns[player] = {
        active = true,
        timeLeft = MountedAttack.KICK_LOCK_SECONDS,
        left = kickLeft,
        right = not kickLeft,
    }
end


---@param key number
function MountedAttack.horseKick(key)
    if key ~= Keyboard.KEY_SPACE then return end

    local player = getSpecificPlayer(0)
    if not player or not player:getVariableBoolean(AnimationVariable.RIDING_HORSE) then return end

    local ks = cooldowns[player]
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

    armKickCooldown(player, kickLeft)

    -- Local knockdown for instant feedback on the rider's own client. In MP the
    -- server applies it for remote clients
    if closest:getHealth() > 0 and closest.knockDown then
        closest:knockDown(true)
    end

    if IS_CLIENT then
        mountcommands.KickRequest:send(player, {
            zombieId = closest:getOnlineID(),
            kickLeft = kickLeft,
        })
    end
end

Events.OnKeyPressed.Add(MountedAttack.horseKick)


-- Server pushes KickPerformed to every client (including the rider) so the
-- mounted-kick animation plays on remote clients
if not IS_SERVER then
    Events.OnInitGlobalModData.Add(function()
        local client = require("HorseMod/networking/client")

        client.registerCommandHandler(mountcommands.KickPerformed, function(args)
            local rider = commands.getPlayer(args.character)
            if not rider then return end

            local kickLeft = args.kickLeft == true
            rider:setVariable(AnimationVariable.KICK_LEFT, kickLeft)
            rider:setVariable(AnimationVariable.KICK_RIGHT, not kickLeft)

            if args.zombieId then
                local cell = getCell()
                if cell then
                    local zombies = cell:getZombieList()
                    for i = 0, zombies:size() - 1 do
                        local z = zombies:get(i)
                        if z and z:getOnlineID() == args.zombieId then
                            if z:getHealth() > 0 and z.knockDown then
                                z:knockDown(true)
                            end
                            break
                        end
                    end
                end
            end

            if not cooldowns[rider] then
                armKickCooldown(rider, kickLeft)
            end
        end)
    end)
end


return MountedAttack
