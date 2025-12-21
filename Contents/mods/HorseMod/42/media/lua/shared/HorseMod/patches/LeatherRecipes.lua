---REQUIREMENTS
local HorseUtils = require("HorseMod/Utils")

--[[
Patches the leather cutting recipe to allow horse leathers as input materials.
The item mappers of this recipe are handled in the `scripts/HorseMod/patches/leathers.txt` file.
]]
local LeatherRecipes = {
    LEATHERS = {
        "HorseMod.HorseLeather_AP_Fur_Tan",
        "HorseMod.HorseLeather_AP_Fur_Tan_Medium",
        "HorseMod.HorseLeather_APHO_Fur_Tan",
        "HorseMod.HorseLeather_APHO_Fur_Tan_Medium",
        "HorseMod.HorseLeather_AQHBR_Fur_Tan",
        "HorseMod.HorseLeather_AQHBR_Fur_Tan_Medium",
        "HorseMod.HorseLeather_AQHP_Fur_Tan",
        "HorseMod.HorseLeather_AQHP_Fur_Tan_Medium",
        "HorseMod.HorseLeather_FBG_Fur_Tan",
        "HorseMod.HorseLeather_FBG_Fur_Tan_Medium",
        "HorseMod.HorseLeather_GDA_Fur_Tan",
        "HorseMod.HorseLeather_GDA_Fur_Tan_Medium",
        "HorseMod.HorseLeather_LPA_Fur_Tan",
        "HorseMod.HorseLeather_LPA_Fur_Tan_Medium",
        "HorseMod.HorseLeather_T_Fur_Tan",
        "HorseMod.HorseLeather_T_Fur_Tan_Medium",
    },
    IDENTIFIER_ITEM = "Base.Leather_Crude_Large",
}

---An example of input identification function. Checks if the input contains an item with a specific full type, which is usually enough to identify it.
---@param input InputScript
---@param loadedItems ArrayList<string>
---@return boolean
LeatherRecipes.identifyInput = function(input, loadedItems)
    if loadedItems:contains(LeatherRecipes.IDENTIFIER_ITEM) then return true end
    return false
end

---Function used to patch a recipe by adding new items to one of its inputs. Uses a `testInput` function to identify the correct input to add items to.
---@param recipeID string
---@param testInput fun(input: InputScript, loadedItems: ArrayList<string>): boolean
---@param itemsToAdd string[]
LeatherRecipes.patchRecipe = function(recipeID, testInput, itemsToAdd)
    -- retrieve the recipe informations
    local craftRecipe = getScriptManager():getCraftRecipe(recipeID)
    local inputs = craftRecipe:getInputs()

    for i = 0, inputs:size() - 1 do
        -- retrieve the input and its script loaded items
        local input = inputs:get(i)
        local loadedItems = HorseUtils.getJavaField(input, "loadedItems") --[[@as ArrayList<string>]]

        -- check if the input passes the test function
        if testInput(input, loadedItems) then
            -- add the items to the input if not already present
            for j = 1, #itemsToAdd do
                local itemToAdd = itemsToAdd[j]
                if not loadedItems:contains(itemToAdd) then
                    loadedItems:add(itemToAdd)
                end
            end
            return
        end
    end
end

LeatherRecipes.patchRecipe("Base.CutLeatherInHalf", LeatherRecipes.identifyInput, LeatherRecipes.LEATHERS)

return LeatherRecipes