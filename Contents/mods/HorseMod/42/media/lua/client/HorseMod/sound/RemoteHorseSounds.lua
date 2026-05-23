---@namespace HorseMod

if isServer() then return end

local Mounts = require("HorseMod/Mounts")
local HorseManager = require("HorseMod/HorseManager")
local commands = require("HorseMod/networking/commands")
local soundcommands = require("HorseMod/networking/soundcommands")
local HorseSoundVolume = require("HorseMod/sound/HorseSoundVolume")
local HorseSoundFootsteps = require("HorseMod/sound/HorseSoundFootsteps")


---@readonly 250 ms remote poll
local POLL_INTERVAL_MS = 250

---@readonly 20 tile sound range with falloff
local SOUND_RANGE = 20
local SOUND_RANGE_SQ = SOUND_RANGE * SOUND_RANGE


---@class RemoteHorseSoundState
---@field gait MovementState
---@field jumping boolean
---@field updatedAt integer

---@type table<IsoAnimal, RemoteHorseSoundState>
local remoteHorseSoundState = {}

local lastPollMs = 0


---@param animal IsoAnimal
---@return BaseCharacterSoundEmitter?
---@nodiscard
local function getAnimalEmitter(animal)
    if not animal then
        return nil
    end
    return animal:getEmitter()
end


---@param animal IsoAnimal
---@return table<string, integer>
local function getSoundIds(animal)
    local modData = animal:getModData()
    modData.horseSoundIds = modData.horseSoundIds or {}
    return modData.horseSoundIds
end


---@param animal IsoAnimal
local function stopAllSoundsOnAnimal(animal)
    local emitter = getAnimalEmitter(animal)
    if not emitter then
        return
    end
    HorseSoundFootsteps.stopAllOn(emitter)
    local soundIds = getSoundIds(animal)
    for name, _ in pairs(soundIds) do
        soundIds[name] = nil
    end
end


---@param fromPlayer IsoPlayer
---@param remote IsoPlayer
---@return number? attenuation
---@nodiscard
local function computeAttenuation(fromPlayer, remote)
    local dx = remote:getX() - fromPlayer:getX()
    local dy = remote:getY() - fromPlayer:getY()
    local dz = remote:getZ() - fromPlayer:getZ()
    local distSq = dx * dx + dy * dy + dz * dz
    if distSq > SOUND_RANGE_SQ then
        return nil
    end

    local t = math.sqrt(distSq) / SOUND_RANGE
    local oneMinusT = 1 - t
    return oneMinusT * oneMinusT
end


---@param emitter BaseCharacterSoundEmitter
---@param animal IsoAnimal
---@param targetSound string
---@param volume number
local function ensureFootstepPlaying(emitter, animal, targetSound, volume)
    local soundIds = getSoundIds(animal)

    if emitter:isPlaying(targetSound) then
        local handle = soundIds[targetSound]
        if handle then
            emitter:setVolume(handle, volume)
        end
        return
    end

    -- Switching gaits: stop any other footstep sound name still playing on this emitter.
    for i = 1, #HorseSoundFootsteps.allFootstepNames do
        local name = HorseSoundFootsteps.allFootstepNames[i]
        if name ~= targetSound then
            if emitter:isPlaying(name) then
                emitter:stopSoundByName(name)
            end
            soundIds[name] = nil
        end
    end

    local handle = emitter:playSoundImpl(targetSound, nil--[[@as IsoObject]])
    emitter:setVolume(handle, volume)
    soundIds[targetSound] = handle
end


---@param remote IsoPlayer
---@param animal IsoAnimal
---@param state RemoteHorseSoundState
---@param baseVolume number
---@param localPlayer IsoPlayer
local function applyRemoteHorseSound(remote, animal, state, baseVolume, localPlayer)
    local emitter = getAnimalEmitter(animal)
    if not emitter then
        return
    end

    local attenuation = computeAttenuation(localPlayer, remote)
    if not attenuation then
        stopAllSoundsOnAnimal(animal)
        return
    end

    local targetSound = HorseSoundFootsteps.getSoundForGait(state.gait, animal:getSquare())
    if not targetSound then
        stopAllSoundsOnAnimal(animal)
        return
    end

    local volume = baseVolume * attenuation
    ensureFootstepPlaying(emitter, animal, targetSound, volume)
end


---@param localPlayer IsoPlayer
local function pollRemoteHorses(localPlayer)
    local baseVolume = HorseSoundVolume.getLive()

    -- state cleanup for any animal in the table that no longer has a rider
    for animal, _ in pairs(remoteHorseSoundState) do
        if not animal:isExistInTheWorld() or animal:isDead() then
            stopAllSoundsOnAnimal(animal)
            remoteHorseSoundState[animal] = nil
        else
            local rider = Mounts.getRider(animal)
            if not rider or rider == localPlayer then
                stopAllSoundsOnAnimal(animal)
                remoteHorseSoundState[animal] = nil
            end
        end
    end

    local onlinePlayers = getOnlinePlayers()
    if not onlinePlayers then
        return
    end

    for i = 0, onlinePlayers:size() - 1 do
        local remote = onlinePlayers:get(i)
        if remote and remote ~= localPlayer then
            local mount = Mounts.getMount(remote)
            if mount then
                local state = remoteHorseSoundState[mount]
                if state then
                    applyRemoteHorseSound(remote, mount, state, baseVolume, localPlayer)
                end
            end
        end
    end
end


---@param player IsoPlayer
local function onPlayerUpdate(player)
    if player ~= getPlayer() then
        return
    end

    local now = getTimestampMs()
    if now - lastPollMs < POLL_INTERVAL_MS then
        return
    end
    lastPollMs = now

    pollRemoteHorses(player)
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)


---@param args HorseSoundStateArguments
local function handleHorseSoundState(args)
    local animal = commands.getAnimal(args.animal)
    if not animal then
        return
    end

    local rider = commands.getPlayer(args.rider)
    local localPlayer = getPlayer()
    if rider and localPlayer and rider == localPlayer then
        -- Local rider's horse is driven by the OnTick SoundsSystem in HorseSounds.lua.
        return
    end

    remoteHorseSoundState[animal] = {
        gait = args.gait,
        jumping = args.jumping == true,
        updatedAt = getTimestampMs(),
    }
end


---@param args HorseSoundOneShotArguments
local function handleHorseSoundOneShot(args)
    local animal = commands.getAnimal(args.animal)
    if not animal then
        return
    end

    local emitter = getAnimalEmitter(animal)
    if not emitter then
        return
    end

    local localPlayer = getPlayer()
    local rider = Mounts.getRider(animal)

    -- Local rider already plays one-shots client-side so we drop it for them
    -- Only remote clients needs this
    if rider and localPlayer and rider == localPlayer then
        return
    end

    local volume = HorseSoundVolume.getLive()
    if rider and localPlayer then
        local attenuation = computeAttenuation(localPlayer, rider)
        if not attenuation then
            return
        end
        volume = volume * attenuation
    elseif localPlayer then
        -- Unmounted horse one-shot
        local dx = animal:getX() - localPlayer:getX()
        local dy = animal:getY() - localPlayer:getY()
        local dz = animal:getZ() - localPlayer:getZ()
        local distSq = dx * dx + dy * dy + dz * dz
        if distSq > SOUND_RANGE_SQ then
            return
        end
        local t = math.sqrt(distSq) / SOUND_RANGE
        local oneMinusT = 1 - t
        volume = volume * (oneMinusT * oneMinusT)
    end

    if emitter:isPlaying(args.sound) then
        emitter:stopSoundByName(args.sound)
    end
    local handle = emitter:playSoundImpl(args.sound, nil--[[@as IsoObject]])
    emitter:setVolume(handle, volume)
end


-- Cleanup hooks.

---@param animal IsoAnimal
HorseManager.onHorseRemoved:add(function(animal)
    stopAllSoundsOnAnimal(animal)
    remoteHorseSoundState[animal] = nil
end)


Mounts.onDismount:add(function(_, dismountedAnimal)
    -- on dismount the server will also broadcast gait as "idle" state, but the poll
    -- handles whichever comes first
    stopAllSoundsOnAnimal(dismountedAnimal)
    remoteHorseSoundState[dismountedAnimal] = nil
end)


Events.OnInitGlobalModData.Add(function()
    local client = require("HorseMod/networking/client")
    client.registerCommandHandler(soundcommands.HorseSoundState, handleHorseSoundState)
    client.registerCommandHandler(soundcommands.HorseSoundOneShot, handleHorseSoundOneShot)
end)


return {}
