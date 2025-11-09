local HorseUtils  = require("HorseMod/Utils")
local HorseRiding = require("HorseMod/Riding")
local Mounting = require("HorseMod/Mounting")
-- local HorseAttachments = require("HorseMod/HorseAttachments")

local function doHorseInteractionMenu(context, player, animal)
    if not animal or not HorseUtils.isHorse(animal) then return end
    if HorseRiding.canMountHorse(player, animal) then
        -- FIXME: currently we set this variable here because animations are still in testing
        -- we should detect when a horse spawns and apply this immediately
        animal:setVariable("isHorse", true)
        context:addOption(getText("IGUI_HorseMod_MountHorse"),
                          player, Mounting.mountHorse, animal)
    end
end

local function onClickedAnimalForContext(playerNum, context, animals, test)
    if test then return end
    if not animals or #animals == 0 then return end
    doHorseInteractionMenu(context, getSpecificPlayer(playerNum), animals[1])
end

Events.OnClickedAnimalForContext.Add(onClickedAnimalForContext)


---@param playerIndex integer
---@return boolean
---@nodiscard
local function joypadHasUIFocus(playerIndex)
    local data = JoypadState.players[playerIndex + 1]

    if not data then
        return false
    end

    return data.focus and data.focus:isVisible() or false
end


---@type table<integer, boolean>
local lastJoypadA = {}


---@param player IsoPlayer
local function handleJoypadMountButton(player)
    local pid = player:getPlayerNum()
    local pad = player:getJoypadBind() or -1
    if pad == -1 then
        lastJoypadA[pid] = false
        return
    end

    local aButton = getJoypadAButton(pad)
    if not aButton or aButton == -1 then
        lastJoypadA[pid] = false
        return
    end

    local pressed = isJoypadPressed(pad, aButton)
    local prev = lastJoypadA[pid] or false
    lastJoypadA[pid] = pressed

    if not pressed or prev then return end
    if joypadHasUIFocus(pid) then return end
    if player:hasTimedActions() then return end
    if player:getVehicle() then return end
    if player:getVariableBoolean("MountingHorse") then return end

    local mountedHorse = HorseRiding.getMountedHorse(player)
    if mountedHorse then
        if player:getVariableBoolean("RidingHorse") then
            Mounting.dismountHorse(player)
        end
        return
    end

    local horse = Mounting.getBestMountableHorse(player, 1.25)
    if horse and horse:isExistInTheWorld() then
        player:setIsAiming(false)
        Mounting.mountHorse(player, horse)
    end
end

Events.OnPlayerUpdate.Add(handleJoypadMountButton)
