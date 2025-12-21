---REQUIREMENTS
local HorseRiding = require("HorseMod/Riding")

--[[
Patches the actions of building and crafting to block while mounted. Craft is only allowed if the recipe is marked as "InHandCraftCraft".
]]
local CraftBlocker = {}

CraftBlocker._originalBuildingIsValid = ISBuildIsoEntity.isValid
function ISBuildIsoEntity:isValid(square)
    if HorseRiding.isMountingHorse(self.character) then
        return false
    end

    return CraftBlocker._originalBuildingIsValid(self, square)
end

CraftBlocker._originalHandCraftValid = ISHandcraftAction.isValid
function ISHandcraftAction:isValid()
    local craftRecipe = self.craftRecipe
    if HorseRiding.isMountingHorse(self.character) then
        if craftRecipe then
            -- if recipe can be made from hand, then allow it
            if not craftRecipe:isInHandCraftCraft() then
                return false
            end
        
        -- no recipe data found, block it in case
        else
            return false
        end
    end
    return CraftBlocker._originalHandCraftValid(self)
end

return CraftBlocker