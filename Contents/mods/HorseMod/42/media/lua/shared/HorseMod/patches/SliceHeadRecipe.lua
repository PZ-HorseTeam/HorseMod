local HorseDefinitions = require('HorseMod/definitions/HorseDefinitions')
local HorseUtils = require("HorseMod/Utils")

local patch = {
    HEADS = {
        "HorseMod.Foal_Head_{id}",
        "HorseMod.Stallion_Head_{id}",
        "HorseMod.Mare_Head_{id}",
    }
}
local HEADS = patch.HEADS

Events.OnGameStart.Add(function()
    local recipe = ScriptManager.instance:getCraftRecipe("SliceHead")
    if recipe then
        local outputs = recipe:getOutputs()
        for i=0, outputs:size()-1 do
            local out = outputs:get(i)
            local mapper = out:getOutputMapper()
            if mapper then
                local list = ArrayList.new()

                -- format possible heads
                for j = 1, #HorseDefinitions.SHORT_NAMES do
                    local id = HorseDefinitions.SHORT_NAMES[j] --[[@as string EmmyLua going fucking schizo]]
                    for k = 1, #HEADS do
                        local template = HEADS[k] --[[@as string EmmyLua going fucking schizo]]
                        local headItem = HorseUtils.formatTemplate(template, {id = id})
                        list:add(headItem)
                    end
                end

                mapper:addOutputEntree("HorseMod.Horse_Skull", list)
                mapper:OnPostWorldDictionaryInit(recipe:getName())
            end
        end
    end
end)

return patch