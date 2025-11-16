local Mount = require("HorseMod/mount/Mount")


---@namespace HorseMod


local HorseRiding = {}


---@type {[integer]: Mount | nil}
HorseRiding.playerMounts = {}


---@param animal IsoAnimal
---@return boolean
---@nodiscard
function HorseRiding.isMountableHorse(animal)
    local type = animal:getAnimalType()
    return type == "stallion" or type == "mare"
end


---@param player IsoPlayer
---@param horse IsoAnimal
---@return boolean
---@nodiscard
function HorseRiding.canMountHorse(player, horse)
    if HorseRiding.playerMounts[player:getPlayerNum()] then
        return false
    end

    return HorseRiding.isMountableHorse(horse)
end


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


---@param rider IsoPlayer
---@return Mount | nil
---@nodiscard
function HorseRiding.getMount(rider)
    return HorseRiding.playerMounts[rider:getPlayerNum()]
end


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


function HorseRiding.updateMounts()
    for _, mount in pairs(HorseRiding.playerMounts) do
        mount:update()
    end
end

Events.OnTick.Add(HorseRiding.updateMounts)


---@param key integer
local function toggleTrot(key)
    if key ~= Keyboard.KEY_X then return end

    local player = getSpecificPlayer(0)
    local mount = HorseRiding.getMount(player)
    if mount and player:getVariableBoolean("RidingHorse") then
        local current = mount.pair.mount:getVariableBoolean("HorseTrot")

        mount.pair:setAnimationVariable("HorseTrot", not current)
    end
end

Events.OnKeyPressed.Add(toggleTrot)


---@param key integer
local function horseJump(key)
    local options = PZAPI.ModOptions:getOptions("HorseMod")
    local jumpKey = Keyboard.KEY_SPACE

    if options then
        -- TODO: move mod options to a module
        local opt = options:getOption("HorseJumpButton")
        assert(opt ~= nil and opt.type == "keybind")
        ---@cast opt umbrella.ModOptions.Keybind
        jumpKey = opt:getValue()
    end

    if key ~= jumpKey then return end

    local player = getSpecificPlayer(0)
    local mount = HorseRiding.getMount(player)
    if mount and player:getVariableBoolean("RidingHorse") and mount.pair.mount:getVariableBoolean("HorseGallop") then
        mount.pair:setAnimationVariable("HorseJump", true)
    end
end

Events.OnKeyPressed.Add(horseJump)


---@param player IsoPlayer
local function initHorseMod(_, player)
    player:setVariable("RidingHorse", false)
    player:setVariable("MountingHorse", false)
    player:setVariable("DismountFinished", false)
    player:setVariable("MountFinished", false)
end

Events.OnCreatePlayer.Add(initHorseMod)


return HorseRiding