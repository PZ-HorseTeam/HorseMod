local HorseRegistries = require("HorseMod/HorseRegistries")

-- add all horse accessories to the forage system
local items = 
    ScriptManager.instance:getItemsTag(HorseRegistries.HorseAccessory)
for i=0, items:size()-1 do
    local item = items:get(i)
    local fullType = item:getFullName()
    forageSystem.addForageDef(
        fullType,
        {
            type = fullType,
            skill = 0,
            xp = 50,
			categories	= { "Junk" },
            zones = {
                Forest	= 1,
                DeepForest	= 1,
                PHForest	= 1,
                PRForest	= 1,
                BirchForest	= 1,
                OrganicForest	= 1,
                Vegitation	= 1,
                FarmLand	= 1,
                TrailerPark	= 1,
                TownZone	= 1,
                ForagingNav	= 1,
            },
            spawnFuncs = { forageSystem.doGenericItemSpawn },
            forceOutside = false,
            canBeAboveFloor = true,
            itemSizeModifier = 0.5,
            isItemOverrideSize = true,
        }
    ) 
end