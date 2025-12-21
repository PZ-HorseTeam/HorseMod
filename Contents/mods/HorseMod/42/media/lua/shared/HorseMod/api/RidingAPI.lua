---@namespace HorseMod

---REQUIREMENTS
local ClothingEquip = require("HorseMod/patches/ClothingEquip")
local ActionBlocker = require("HorseMod/patches/ActionBlocker")

local RidingAPI = {}

---Add a body location restriction while mounting a horse. By default, body locations are restricted from being equipped/unequipped while mounted unless explicitly allowed in the :lua:obj:`HorseMod.patches.ClothingEquip.allowedLocations` table.
---@param bodyLocation string The body location to restrict. This is the body location registries entry, e.g., ``base:hat``.
---@param canEquip boolean Whether the body location can be equipped while mounted on a horse.
RidingAPI.addBodyLocationRestriction = function(bodyLocation, canEquip)
    ClothingEquip.allowedLocations[bodyLocation] = canEquip
end


---Add a valid timed action while mounting a horse. By default, only a few timed actions are allowed while mounted.
---@param actionName string The name of the timed action to allow.
RidingAPI.addValidTimedAction = function(actionName)
    ActionBlocker.validActions[actionName] = true
end

return RidingAPI