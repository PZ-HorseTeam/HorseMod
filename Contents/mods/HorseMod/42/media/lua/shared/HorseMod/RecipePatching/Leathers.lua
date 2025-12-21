local HorseUtils = require("HorseMod/Utils")

local items = {
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
}


local checkItem = "Base.Leather_Crude_Large"

---An example of input identification function. Checks if the input contains an item with a specific full type, which is usually enough to identify it.
---@param input InputScript
---@param loadedItems ArrayList<string>
---@return boolean
local function identifyInput(input, loadedItems)
    if loadedItems:contains(checkItem) then return true end
    return false
end

---Function used to patch a recipe by adding new items to one of its inputs. Uses a `testInput` function to identify the correct input to add items to.
---@param recipeID string
---@param testInput fun(input: InputScript, loadedItems: ArrayList<string>): boolean
---@param itemsToAdd string[]
local function patchRecipe(recipeID, testInput, itemsToAdd)
    -- retrieve the recipe informations
    local craftRecipe = getScriptManager():getCraftRecipe(recipeID)
    local inputs = craftRecipe:getInputs()

    for i = 0, inputs:size() - 1 do
        -- retrieve the input and its script loaded items
        local input = inputs:get(i)
        local loadedItems = HorseUtils.getJavaField(input, "loadedItems") --[[@as ArrayList<string>]]

        -- check if the input passes the test function
        if testInput(input, loadedItems) then
            -- add the items to the input
            for j = 1, #itemsToAdd do
                loadedItems:add(itemsToAdd[j])
            end
            return
        end
    end
end

patchRecipe("Base.CutLeatherInHalf", identifyInput, items)
