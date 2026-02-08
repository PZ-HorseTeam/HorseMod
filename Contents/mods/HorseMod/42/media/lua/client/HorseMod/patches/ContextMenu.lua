---REQUIREMENTS
local Mounts = require("HorseMod/Mounts")
local HorseUtils = require("HorseMod/Utils")
local MountingUtility = require("HorseMod/mounting/MountingUtility")
local Mounting = require("HorseMod/Mounting")


local patch = {}


---SIT ON THE GROUND PATCH

local original_ISWorldObjectContextMenu_onSitOnGround = ISWorldObjectContextMenu.onSitOnGround

---Patch sit on ground so it can't be done if the player is riding a horse. 
---Safeguard for other sources of sitting on the ground than context menu.
ISWorldObjectContextMenu.onSitOnGround = function(player)
    if Mounts.hasMount(getSpecificPlayer(player)) then
        return
    end
    return original_ISWorldObjectContextMenu_onSitOnGround(player)
end

---@param playerNum integer
---@param context ISContextMenu
---@param worldObjects IsoObject[]
---@param test boolean
patch.onFillWorldObjectContextMenu = function(playerNum, context, worldObjects, test)
    local player = getSpecificPlayer(playerNum)
    if Mounts.hasMount(player) then
        context:removeOptionByName(getText("ContextMenu_SitGround"))
    end
end

Events.OnFillWorldObjectContextMenu.Add(patch.onFillWorldObjectContextMenu)


local original_AnimalContextMenu_showRadialMenu = AnimalContextMenu.showRadialMenu
function AnimalContextMenu.showRadialMenu(player)
    original_AnimalContextMenu_showRadialMenu(player)

    -- retrieve animal and verify it's a mountable horse
    local animal = AnimalContextMenu.getAnimalToInteractWith(player)
    if not animal or not HorseUtils.isHorse(animal) then return end

    -- retrieve radial menu
    local playerIndex = player:getPlayerNum()
    local menu = getPlayerRadialMenu(playerIndex)
    if not menu then return end

    local mountPosition = MountingUtility.getNearestMountPosition(player, animal)

    local playerMount = Mounts.getMount(player)
    
    --- DISMOUNTING
    if playerMount == animal then
        menu:addSlice(
            getText("ContextMenu_Horse_Dismount", animal:getFullName()),
            getTexture("media/ui/HorseMod/dismount_contextual.png"),
            Mounting.dismountHorse,
            player, playerMount, mountPosition
        )

    --- MOUNTING
    else
        local canMount, reason = MountingUtility.canMountHorse(player, animal)
        if not canMount then return end

        menu:addSlice(
            getText("ContextMenu_Horse_Mount", animal:getFullName()),
            getTexture("media/ui/HorseMod/mount_contextual.png"),
            Mounting.mountHorse,
            player, animal, mountPosition
        )
    end
end



return patch