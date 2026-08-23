---REQUIREMENTS
local AnimationVariable = require('HorseMod/definitions/AnimationVariable')
local Mount = require("HorseMod/mount/Mount")
local Mounts = require("HorseMod/Mounts")
local MountPair = require("HorseMod/MountPair")
local HorseUtils = require("HorseMod/Utils")
local HorseSounds = require("HorseMod/HorseSounds")
local HorseDamage = require("HorseMod/horse/HorseDamage")
local MountAction = require("HorseMod/TimedActions/MountAction")
local DismountAction = require("HorseMod/TimedActions/DismountAction")
local Mounting = require("HorseMod/Mounting")
local MountingUtility = require("HorseMod/mounting/MountingUtility")
local HorseManager = require("HorseMod/HorseManager")
local RemoteMountInterp = require("HorseMod/mount/RemoteMountInterp")
require("HorseMod/mount/RemoteRiderPin")
local PendingRidingState = require("HorseMod/mount/PendingRidingState")
local mountcommands = require("HorseMod/networking/mountcommands")
local commands = require("HorseMod/networking/commands")
local netmetrics = require("HorseMod/networking/netmetrics")
local relevance = require("HorseMod/networking/relevance")
local ridingcodec = require("HorseMod/networking/ridingcodec")


---@namespace HorseMod

---Holds horse riding utility and keybind handling.
local HorseRiding = {
    ---Holds the mount of a given player ID.
    ---@type {[integer]: Mount | nil}
    playerMounts = {},
}

---Retrieve the player mount
---@param rider IsoPlayer
---@return Mount | nil
---@nodiscard
function HorseRiding.getMount(rider)
    return HorseRiding.playerMounts[rider:getPlayerNum()]
end

---Create a new mount from a pair.
---@param pair MountPair
---@return Mount
function HorseRiding.createMountFromPair(pair)
    assert(
        HorseRiding.getMount(pair.rider) == nil,
        "tried to create mount for a player that is already mounted"
    )

    local mount = Mount.new(pair)
    HorseRiding.playerMounts[pair.rider:getPlayerNum()] = mount

    pair.rider:getModData().remountAnimal = pair.mount:getAnimalID()

    -- this won't work anyway, this is a client module!
    -- i don't think remounting is viable in multiplayer anyway, so it's fine for this to not work in mp
    -- pair.rider:transmitModData()

    return mount
end

---Remove the mount from a player.
---@param player IsoPlayer
function HorseRiding.removeMount(player)
    local mount = HorseRiding.getMount(player)
    assert(
        mount ~= nil,
        "tried to remove mount from a player that is not mounted"
    )

    mount:cleanup()

    HorseRiding.playerMounts[mount.pair.rider:getPlayerNum()] = nil

    mount.pair.rider:getModData().remountAnimal = nil
end

---@param player IsoPlayer
---@param animal IsoAnimal
Mounts.onMount:add(function(player, animal)
    if not player:isLocalPlayer() then
        return
    end

    local mount = HorseRiding.getMount(player)
    if mount then
        if mount.pair.mount == animal then
            return
        end
        HorseRiding.removeMount(player)
    end

    HorseRiding.createMountFromPair(
        MountPair.new(
            player,
            animal
        )
    )
end)

---@param player IsoPlayer
---@param dismountedAnimal IsoAnimal?
Mounts.onDismount:add(function(player, dismountedAnimal)
    HorseRiding.lastAppliedState[player] = nil
    if dismountedAnimal then
        PendingRidingState.clear(
            ridingcodec.encodePlayerId(player),
            commands.getAnimalId(dismountedAnimal)
        )
    end

    if not player:isLocalPlayer() then
        RemoteMountInterp.clear(player)
        return
    end

    if HorseRiding.getMount(player) then
        HorseRiding.removeMount(player)
    end
end)

---Newest riding-state sequence applied per rider, used to drop duplicate and
---out-of-order snapshots. Command packets are reliable but not ordered.
---@type table<IsoPlayer, {animal: integer, seq: integer}>
HorseRiding.lastAppliedState = {}

---@param args RidingStateArguments
---@return boolean applied
local function applyResolvedState(args)
    local player = ridingcodec.decodePlayerId(args.character)
    local animal = commands.getAnimal(args.animal)
    if not player or not animal then
        return false
    end

    local tracked = HorseRiding.lastAppliedState[player]
    if tracked and tracked.animal == args.animal and args.seq <= tracked.seq then
        if netmetrics.enabled then
            netmetrics.count("riding.clientStaleRejected")
        end
        return true
    end

    if player:isLocalPlayer() then
        local mount = HorseRiding.getMount(player)
        if not mount then
            return false
        end
        mount:applyAuthoritativeState(args)
    else
        RemoteMountInterp.push(player, animal, args)
    end

    if tracked and tracked.animal == args.animal then
        tracked.seq = args.seq
    else
        HorseRiding.lastAppliedState[player] = {
            animal = args.animal,
            seq = args.seq,
        }
    end

    return true
end

---Update the horse riding for every mounts.
local function updateMounts()
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player then
            local mount = HorseRiding.getMount(player)
            if mount then
                mount:update()
            end
        end
    end

    PendingRidingState.flush(applyResolvedState)
end

HorseManager.preUpdate:add(updateMounts)

---@param wire RidingStateWire
local function applyRidingState(wire)
    local args = ridingcodec.decode(wire)
    if not args then
        if netmetrics.enabled then
            netmetrics.count("riding.clientDecodeRejected")
        end
        return
    end

    if not applyResolvedState(args) then
        PendingRidingState.store(args)
        if netmetrics.enabled then
            netmetrics.count("riding.clientPendingStored")
        end
    end
end

Events.OnInitGlobalModData.Add(function()
    local client = require("HorseMod/networking/client")
    client.registerCommandHandler(mountcommands.RidingState, applyRidingState)
end)

---Handle keybind pressing to switch horse riding states.
---@param key integer
HorseRiding.onKeyPressed = function(key)
    local player = getPlayer()
    if not player then
        return
    end

    -- cancel dismount or mount action if possible
    if key == getCore():getKey("Interact") then
        local queue = ISTimedActionQueue.getTimedActionQueue(player)
        local currentAction = queue.current
        if currentAction then
            if currentAction.Type == DismountAction.Type
                or currentAction.Type == MountAction.Type then
                if not player:getVariableBoolean(AnimationVariable.NO_CANCEL) then
                    currentAction:forceStop()
                    return
                end
            end
        end
    end

    -- start dismount when Interact is pressed while mounted
    if key == getCore():getKey("Interact") then
        local mountedMount = HorseRiding.getMount(player)
        if mountedMount then
            if player:hasTimedActions() then return end
            if player:getVariableBoolean(AnimationVariable.DISMOUNT_STARTED) then return end

            local horse = mountedMount.pair.mount
            local mountPosition = MountingUtility.getNearestMountPosition(player, horse)
            if not mountPosition then return end

            Mounting.dismountHorse(player, horse, mountPosition)
            return
        end
    end

    -- update mount input
    local mount = HorseRiding.getMount(player)
    if mount then
        mount:keyPressed(key)
    end
end

Events.OnKeyPressed.Add(HorseRiding.onKeyPressed)


-- TODO: this function needs to be split between client and server
---@param character IsoGameCharacter
HorseRiding.dismountOnHorseDeath = function(character)
    if not character:isAnimal() then
        return
    end
    ---@cast character IsoAnimal

    local rider = Mounts.getRider(character)
    if rider and rider:isLocalPlayer() then
        local mount = HorseRiding.getMount(rider)
        assert(mount ~= nil)
        HorseSounds.playSound(character, HorseSounds.Sound.DEATH)

        HorseUtils.runAfter(
            0.5,
            function()
                HorseDamage.knockDownNearbyZombies(mount.pair.mount)
            end
        )
    end
end

Events.OnCharacterDeath.Add(HorseRiding.dismountOnHorseDeath)


---@param player IsoPlayer
local function initHorseMod(_, player)
    player:setVariable(AnimationVariable.RIDING_HORSE, false)
    player:setVariable(AnimationVariable.MOUNTING_HORSE, false)

    if isClient() then
        PendingRidingState.clearAll()
        mountcommands.RequestMounts:send(
            player,
            {
                w = relevance.getLocalChunkGridWidth(),
            }
        )
    elseif isServer() then
        return
    else
        return
    end
end

Events.OnCreatePlayer.Add(initHorseMod)


return HorseRiding
