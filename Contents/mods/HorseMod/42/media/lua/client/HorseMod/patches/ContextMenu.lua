---REQUIREMENTS
local Mounts = require("HorseMod/Mounts")


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

---@parma playerNum number
---@param context ISContextMenu
---@param worldObjects table<IsoObject>
---@param test boolean
patch.onFillWorldObjectContextMenu = function(playerNum, context, worldObjects, test)
    local player = getSpecificPlayer(playerNum)
    if Mounts.hasMount(player) then
        context:removeOptionByName(getText("ContextMenu_SitGround"))
    end
end



Events.OnFillWorldObjectContextMenu.Add(patch.onFillWorldObjectContextMenu)

return patch