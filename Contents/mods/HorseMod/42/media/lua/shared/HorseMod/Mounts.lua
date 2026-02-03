local mountcommands = require("HorseMod/networking/mountcommands")
local commands = require("HorseMod/networking/commands")
local Event = require("HorseMod/Event")
local AnimationVariable = require("HorseMod/definitions/AnimationVariable")

local IS_CLIENT = isClient()
local IS_SERVER = isServer()

---@param text string
---@param ... any
local function log(text, ...)
    DebugLog.log("[HorseMod] [Mounts] " .. string.format(text, ...))
end


---@type table<IsoPlayer, integer>
local playerMountMap = {}

---@type table<integer, IsoPlayer>
local mountPlayerMap = {}

local Mounts = {}

---Triggered when a player's mount changes.
Mounts.onMountChanged = Event.new--[[@<IsoPlayer, IsoAnimal?>]]()

---@param player IsoPlayer
---@param id integer
local function addMountID(player, id)
    local oldMount = playerMountMap[player]
    if oldMount then
        if oldMount == id then
            return
        end
        Mounts.removeMount(player)
    end

    playerMountMap[player] = id
    mountPlayerMap[id] = player
end

---@param player IsoPlayer
---@param animal IsoAnimal
function Mounts.addMount(player, animal)
    local oldMount = Mounts.getMount(player)
    if oldMount then
        if oldMount == animal then
            return
        end
        Mounts.removeMount(player)
    end

    addMountID(player, commands.getAnimalId(animal))

    animal:getBehavior():setBlockMovement(true)
    animal:stopAllMovementNow()
    animal:setVariable(AnimationVariable.RIDING_HORSE, true)

    if IS_SERVER then
        mountcommands.Mount:send(
            nil,
            {
                animal = commands.getAnimalId(animal),
                character = commands.getPlayerId(player),
            }
        )
    end

    Mounts.onMountChanged:trigger(player, animal)
end

---@param player IsoPlayer
local function removeMountID(player)
    local id = playerMountMap[player]
    playerMountMap[player] = nil
    mountPlayerMap[id] = nil
end

---@param player IsoPlayer
function Mounts.removeMount(player)
    if not Mounts.hasMount(player) then
        return
    end

    local mountId = playerMountMap[player]
    removeMountID(player)

    local mount = commands.getAnimal(mountId)
    if mount then
        mount:getBehavior():setBlockMovement(false)
        mount:setVariable(AnimationVariable.RIDING_HORSE, false)

        -- used to reset the wander counter of the horse so it doesn't instantly wander off
        mount:setStateEventDelayTimer(mount:getBehavior():pickRandomWanderInterval())
    elseif not IS_CLIENT then
        -- it should only be possible on multiplayer clients for the mount to be unloaded
        log("WEIRD: player %s dismounted unknown animal id=%d", player:getUsername(), mountId)
    end

    if IS_SERVER then
        mountcommands.Dismount:send(
            nil,
            {
                character = commands.getPlayerId(player)
            }
        )
    end

    Mounts.onMountChanged:trigger(player, nil)
end

---@param player IsoPlayer
---@return boolean
---@nodiscard
function Mounts.hasMount(player)
    return playerMountMap[player] ~= nil
end

---Returns a player's mount.
---Nil may be returned if the player is not mounted or the mount is not in the currently loaded area.
---Use :lua:obj:`hasMount` instead to check if the player is mounted.
---@param player IsoPlayer
---@return IsoAnimal? mount
---@nodiscard
function Mounts.getMount(player)
    if not playerMountMap[player] then
        return nil
    end

    return commands.getAnimal(playerMountMap[player])
end

---@param animal IsoAnimal
---@return boolean
---@nodiscard
function Mounts.hasRider(animal)
    return mountPlayerMap[commands.getAnimalId(animal)] ~= nil
end

---Returns an animal's rider.
---Nil may be returned if the animal is not mounted or the rider is not currently loaded.
---Use :lua:obj:`hasMount` instead to check if the player is mounted.
---@param animal IsoAnimal
---@return IsoPlayer? rider
---@nodiscard
function Mounts.getRider(animal)
    return mountPlayerMap[commands.getAnimalId(animal)]
end

function Mounts.reset()
    for player, _ in pairs(playerMountMap) do
        Mounts.removeMount(player)
    end
end

---Reapply block movement every tick because it has a timeout
local function updateMounts()
    for player, mount in pairs(playerMountMap) do
        local animal = commands.getAnimal(mount)
        if not animal then
            log("WEIRD: tried to update unknown animal id=%d player=%s", mount, player:getUsername())
        else
            animal:getBehavior():setBlockMovement(true)
        end
    end
end

---@param character IsoGameCharacter
local function dismountOnDeath(character)
    if not instanceof(character, "IsoPlayer") then
        return
    end
    ---@cast character IsoPlayer

    Mounts.removeMount(character)
end

if not isClient() then
    Events.OnTick.Add(updateMounts)
    Events.OnCharacterDeath.Add(dismountOnDeath)
end


-- we don't actually need these in singleplayer but networking.client complains if there is no handler
if not IS_SERVER then
    -- need to delay this require :(
    Events.OnInitGlobalModData.Add(function()
        local client = require("HorseMod/networking/client")

        client.registerCommandHandler(mountcommands.Mount, function(args)
            local player = commands.getPlayer(args.character)
            if player then
                local animal = commands.getAnimal(args.animal)
                if animal then
                    Mounts.addMount(player, animal)
                else
                    addMountID(player, args.animal)
                end
            else
                log("received Mount command for unknown player id=%d", args.character)
            end
        end)

        client.registerCommandHandler(mountcommands.Dismount, function(args)
            local player = commands.getPlayer(args.character)
            if player then
                Mounts.removeMount(player)
            else
                log("received Dismount command for unknown player id=%d", args.character)
            end
        end)

        client.registerCommandHandler(mountcommands.SendMounts, function(args)
            Mounts.reset()
    
            for playerId, animalId in pairs(args.mounts) do
                local player = commands.getPlayer(playerId)
                local animal = commands.getAnimal(animalId)
                if not player then
                    log(
                        "could not find player or animal sent by server, player=%d animal=%d",
                        playerId,
                        animalId
                    )
                else
                    if animal then
                        Mounts.addMount(player, animal)
                    else
                        addMountID(player, animalId)
                    end
                end
            end
        end)
    end)
end


return Mounts