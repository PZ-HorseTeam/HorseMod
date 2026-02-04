local HorseUtils  = require("HorseMod/Utils")
local Mounts = require("HorseMod/Mounts")
local Mounting = require("HorseMod/Mounting")
local AnimationVariable = require('HorseMod/definitions/AnimationVariable')
local MountingUtility = require("HorseMod/mounting/MountingUtility")


---@param context ISContextMenu
---@param player IsoPlayer
---@param animal IsoAnimal
local function doHorseInteractionMenu(context, player, animal)
    local playerMount = Mounts.getMount(player)

    if playerMount ~= animal then
        local canMount, reason = MountingUtility.canMountHorse(player, animal)
        
        -- skip if can't mount and no reason, it means the horse can't be mounted
        -- for reasons that don't need to be shown to the player (i.e. butcher hook)
        if not canMount and not reason then return end

        local mountPosition = MountingUtility.getNearestMountPosition(player, animal)
        local option = context:addOption(
            getText("ContextMenu_Horse_Mount", animal:getFullName()),
            player, Mounting.mountHorse, animal, mountPosition
        )
        option.iconTexture = animal:getInventoryIconTexture()
        local tooltip
        if not mountPosition then
            option.notAvailable = true
            tooltip = ISWorldObjectContextMenu.addToolTip()
            tooltip.description = getText("ContextMenu_Horse_NoMountPosition")
        elseif not canMount then
            option.notAvailable = true
            if reason then
                tooltip = ISWorldObjectContextMenu.addToolTip()
                tooltip.description = getText(reason)
            end
        end
        if tooltip then
            option.toolTip = tooltip
        end
    else
        local dismountPosition = MountingUtility.getNearestMountPosition(player, animal)
        local dismountOption = context:addOption(
            getText("ContextMenu_Horse_Dismount", animal:getFullName()),
            player, Mounting.dismountHorse, playerMount, dismountPosition
        )
        dismountOption.iconTexture = animal:getInventoryIconTexture()
        if not dismountPosition then
            dismountOption.notAvailable = true
            local tooltip = ISWorldObjectContextMenu.addToolTip()
            tooltip.description = getText("ContextMenu_Horse_NoMountPosition")
            dismountOption.toolTip = tooltip
        end
    end
end

local function onClickedAnimalForContext(playerNum, context, animals, test)
    if test then return end
    if not animals or #animals == 0 then return end

    -- retrieve first horse instance
    local horse
    for i = 1, #animals do
        local animal = animals[i]
        if HorseUtils.isHorse(animal) then
            horse = animal
            break
        end
    end
    if not horse then return end

    doHorseInteractionMenu(context, getSpecificPlayer(playerNum), horse)
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
    if player:getVehicle() then return end

    local mountedHorse = Mounts.getMount(player)
    if player:hasTimedActions() and not mountedHorse then return end
    if mountedHorse and player:getVariableBoolean(AnimationVariable.DISMOUNT_STARTED) then return end

    -- dismount current horse if riding one
    if mountedHorse then
        if player:getVariableBoolean(AnimationVariable.RIDING_HORSE) then
            local mountPosition = MountingUtility.getNearestMountPosition(player, mountedHorse)
            if not mountPosition then return end
            Mounting.dismountHorse(player, mountedHorse, mountPosition)
        end
        return
    end

    -- mount nearest horse
    local horse = MountingUtility.getBestMountableHorse(player, 1.25)
    if horse and horse:isExistInTheWorld() and MountingUtility.canMountHorse(player, horse) then
        local mountPosition = MountingUtility.getNearestMountPosition(player, horse)
        if not mountPosition then return end
        player:setIsAiming(false)
        Mounting.mountHorse(player, horse, mountPosition)
    end
end

Events.OnPlayerUpdate.Add(handleJoypadMountButton)
