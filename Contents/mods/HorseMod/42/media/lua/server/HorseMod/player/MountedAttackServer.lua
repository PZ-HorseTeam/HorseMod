if not isServer() then return end

local commands = require("HorseMod/networking/commands")
local mountcommands = require("HorseMod/networking/mountcommands")
local server = require("HorseMod/networking/server")
local Mounts = require("HorseMod/Mounts")

local KICK_RANGE_SQ = 2.5 * 2.5

---@param cell IsoCell
---@param onlineId integer
---@return IsoZombie?
---@nodiscard
local function findZombieByOnlineID(cell, onlineId)
    local zombies = cell:getZombieList()
    if not zombies then return nil end
    for i = 0, zombies:size() - 1 do
        local z = zombies:get(i)
        if z and z:getOnlineID() == onlineId then
            return z
        end
    end
    return nil
end


server.registerCommandHandler(mountcommands.KickRequest, function(sender, args)
    if not sender or not args then
        return
    end

    if not Mounts.getMount(sender) then
        return
    end

    local cell = sender:getCell()
    if not cell then
        return
    end

    local zombie = findZombieByOnlineID(cell, args.zombieId)
    if not zombie then
        return
    end

    if zombie:getHealth() <= 0 then
        return
    end

    local dx = zombie:getX() - sender:getX()
    local dy = zombie:getY() - sender:getY()
    local d2 = dx * dx + dy * dy
    if d2 > KICK_RANGE_SQ then
        return
    end

    if zombie.knockDown then
        zombie:knockDown(true)
    end

    mountcommands.KickPerformed:send(nil, {
        character = commands.getPlayerId(sender),
        kickLeft = args.kickLeft == true,
        zombieId = args.zombieId,
    })
end)
