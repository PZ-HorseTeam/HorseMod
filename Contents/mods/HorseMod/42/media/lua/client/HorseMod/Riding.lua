---REQUIREMENTS
local Mount = require("HorseMod/mount/Mount")
local HorseUtils = require("HorseMod/Utils")
local ModOptions = require("HorseMod/ModOptions")

---@namespace HorseMod

---Holds horse riding utility and keybind handling.
local HorseRiding = {
    ---Holds the mount of a given player ID.
    ---@type {[integer]: Mount | nil}
    playerMounts = {},
}

---@deprecated
---@param animal IsoAnimal
---@return boolean
---@nodiscard
function HorseRiding.isMountableHorse(animal)
    return HorseUtils.isAdult(animal)
end

---Verify that the player can mount a horse.
---@param player IsoPlayer
---@param horse IsoAnimal
---@return boolean
---@return string?
---@nodiscard
function HorseRiding.canMountHorse(player, horse)
    -- already mounted
    if HorseRiding.playerMounts[player:getPlayerNum()] then
        return false

    --dead
    elseif horse:isDead() then
        return false, "IsDead"

    -- on butcher hook
    elseif horse:isOnHook() then
        return false
    
    -- -- running
    -- elseif horse:getVariableBoolean("animalRunning") then
    --     return false, "IsRunning"
    
    -- not an adult horse
    elseif not HorseUtils.isAdult(horse) then
        return false, "NotAdult"
    end

    return true
end

---Retrieve the mount of the player.
---@param player IsoPlayer
---@return IsoAnimal | nil
---@nodiscard
function HorseRiding.getMountedHorse(player)
    local mount = HorseRiding.playerMounts[player:getPlayerNum()]
    if not mount then
        return nil
    end

    return mount.pair.mount
end

---Retrieve the player mount
---@param rider IsoPlayer
---@return Mount | nil
---@nodiscard
function HorseRiding.getMount(rider)
    return HorseRiding.playerMounts[rider:getPlayerNum()]
end

---Create a new mount from a pair.
---@param pair MountPair
function HorseRiding.createMountFromPair(pair)
    assert(
        HorseRiding.getMount(pair.rider) == nil,
        "tried to create mount for a player that is already mounted"
    )

    HorseRiding.playerMounts[pair.rider:getPlayerNum()] = Mount.new(pair)

    local modData = pair.rider:getModData()
    modData.ShouldRemount = true
    pair.rider:transmitModData()
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

    UpdateHorseAudio(mount.pair.rider)

    HorseRiding.playerMounts[mount.pair.rider:getPlayerNum()] = nil

    local modData = mount.pair.rider:getModData()
    modData.ShouldRemount = false
    mount.pair.rider:transmitModData()
end

---Update the horse riding for every mounts.
HorseRiding.updateMounts = function()
    for _, mount in pairs(HorseRiding.playerMounts) do
        mount:update()
    end
end

Events.OnTick.Add(HorseRiding.updateMounts)


---Handle keybind pressing to switch horse riding states.
---@param key integer
HorseRiding.onKeyPressed = function(key)
    ---TROT
    if key == ModOptions.HorseTrotButton then
        local player = getPlayer()
        local mount = HorseRiding.getMount(player)
        if not mount then return end

        if player:getVariableBoolean("RidingHorse") then
            local mountPair = mount.pair
            local current = mountPair.mount:getVariableBoolean("HorseTrot")
            mountPair:setAnimationVariable("HorseTrot", not current)
        end

    ---JUMP
    elseif key == ModOptions.HorseJumpButton then
        local player = getPlayer()
        local mount = HorseRiding.getMount(player)
        if not mount then return end

        local mountPair = mount.pair
        local horse = mountPair.mount
        if player:getVariableBoolean("RidingHorse") 
            and horse:getVariableBoolean("HorseGallop")
            and not mountPair:getAnimationVariableBoolean("HorseJump") then
            mountPair:setAnimationVariable("HorseJump", true)
        end
    end
end

Events.OnKeyPressed.Add(HorseRiding.onKeyPressed)


HorseRiding.dismountOnHorseDeath = function(character)
    if not character:isAnimal() or not HorseRiding.isMountableHorse(character) then
        return
    end

    for _, mount in pairs(HorseRiding.playerMounts) do
        if mount and mount.pair.mount == character then
            local rider = mount.pair.rider
            HorseRiding.removeMount(rider)
            HorseUtils.runAfter(4.1, function()
                    rider:setBlockMovement(false)
                    rider:setIgnoreMovement(false)
                    rider:setIgnoreInputsForDirection(false)
                    rider:setVariable("HorseDying", false)
                end)
            return
        end
    end
end

Events.OnCharacterDeath.Add(HorseRiding.dismountOnHorseDeath)


---@param player IsoPlayer
local function initHorseMod(_, player)
    player:setVariable("RidingHorse", false)
    player:setVariable("MountingHorse", false)
    player:setVariable("DismountFinished", false)
    player:setVariable("MountFinished", false)
end

Events.OnCreatePlayer.Add(initHorseMod)


return HorseRiding