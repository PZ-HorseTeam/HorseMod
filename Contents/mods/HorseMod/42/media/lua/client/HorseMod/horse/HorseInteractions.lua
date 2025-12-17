local HorseUtils  = require("HorseMod/Utils")
local HorseRiding = require("HorseMod/Riding")
local Mounting = require("HorseMod/Mounting")
local AnimationVariables = require("HorseMod/AnimationVariables")
-- local HorseAttachments = require("HorseMod/HorseAttachments")

---@param context ISContextMenu
---@param player IsoPlayer
---@param animal IsoAnimal
local function doHorseInteractionMenu(context, player, animal)
    local canMount, reason = HorseRiding.canMountHorse(player, animal)
    local option = context:addOption(
        getText("IGUI_HorseMod_MountHorse"),
        player, Mounting.mountHorse, animal
    )
    option.iconTexture = animal:getInventoryIconTexture()
    if not canMount and reason then
        local tooltip = ISWorldObjectContextMenu.addToolTip()
        tooltip.description = getText("ContextMenu_Horse_"..reason)
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
    if player:getVariableBoolean(AnimationVariables.MOUNTING_HORSE) then return end

    local mountedHorse = HorseRiding.getMountedHorse(player)
    if mountedHorse then
        if player:getVariableBoolean(AnimationVariables.RIDING_HORSE) then
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
