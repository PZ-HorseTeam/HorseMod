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
---@param animal IsoAnimal?
Mounts.onMountChanged:add(function(player, animal)
    if not player:isLocalPlayer() then
        return
    end

    if HorseRiding.getMount(player) then
        HorseRiding.removeMount(player)
    end

    if animal then
        HorseRiding.createMountFromPair(
            MountPair.new(
                player,
                animal
            )
        )
    end
end)

---Update the horse riding for every mounts.
local function updateMounts()
    for i = 0, getNumActivePlayers() do
        local player = getSpecificPlayer(i)
        if player then
            local mount = HorseRiding.getMount(player)
            if mount then
                mount:update()
            end
        end
    end
end

Events.OnTick.Add(updateMounts)

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

    for _, mount in pairs(HorseRiding.playerMounts) do
        if mount.pair.mount == character then
            HorseSounds.playSound(character, HorseSounds.Sound.DEATH)

            HorseUtils.runAfter(
                0.5,
                function()
                    HorseDamage.knockDownNearbyZombies(mount.pair.mount)
                end
            )
            return
        end
    end
end

Events.OnCharacterDeath.Add(HorseRiding.dismountOnHorseDeath)


---@param player IsoPlayer
local function initHorseMod(_, player)
    player:setVariable(AnimationVariable.RIDING_HORSE, false)
    player:setVariable(AnimationVariable.MOUNTING_HORSE, false)
end

Events.OnCreatePlayer.Add(initHorseMod)


return HorseRiding