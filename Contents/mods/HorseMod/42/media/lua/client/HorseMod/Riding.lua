---REQUIREMENTS
local Mount = require("HorseMod/mount/Mount")
local HorseUtils = require("HorseMod/Utils")
local AnimationVariable = require("HorseMod/AnimationVariable")
local Mounts = require("HorseMod/Mounts")

local MountPair = require("HorseMod/MountPair")
local HorseDamage = require("HorseMod/horse/HorseDamage")
local HorseSounds = require("HorseMod/HorseSounds")

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

    local modData = pair.rider:getModData()
    modData.ShouldRemount = true
    pair.rider:transmitModData()

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

    local modData = mount.pair.rider:getModData()
    modData.ShouldRemount = false
    mount.pair.rider:transmitModData()
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
            local rider = mount.pair.rider
            Mounts.removeMount(rider)

            HorseSounds.playSound(character, HorseSounds.Sound.DEATH)

            HorseUtils.runAfter(
                0.5,
                function()
                    HorseDamage.knockDownNearbyZombies(mount.pair.mount)
                end
            )

            HorseUtils.runAfter(
                4.1,
                function()
                    rider:setBlockMovement(false)
                    rider:setIgnoreMovement(false)
                    rider:setIgnoreInputsForDirection(false)
                    rider:setVariable(AnimationVariable.DYING, false)
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
    player:setVariable(AnimationVariable.DISMOUNT_FINISHED, false)
    player:setVariable(AnimationVariable.MOUNT_FINISHED, false)
end

Events.OnCreatePlayer.Add(initHorseMod)


return HorseRiding