require("Items/ProceduralDistributions")

local module = {}


module.TARGET_SOURCE = 'JacquesBeaver'
module.TO_ADD = 'HorseMod.CricketHorse'

-- distribution
module.targetDistributions = {
    ClutterTables.BinItems,

    SuburbsDistributions['all']['Outfit_Evacuee'].items,
    SuburbsDistributions['Bag_BirthdayBasket'].items,
    SuburbsDistributions['Bag_HospitalBasket'].items,
    SuburbsDistributions['Bag_Schoolbag_Kids'].items,

    ProceduralDistributions.list['BedroomDresserChild'].items,
    ProceduralDistributions.list['BedroomSidetableChild'].items,
    ProceduralDistributions.list['CarnivalPrizes'].items,
    ProceduralDistributions.list['CrateSpiffoMerch'].items,
    ProceduralDistributions.list['CrateToys'].items,
    ProceduralDistributions.list['DaycareCounter'].items,
    ProceduralDistributions.list['DaycareDesk'].items,
    ProceduralDistributions.list['DaycareShelves'].items,
    ProceduralDistributions.list['Gifts'].items,
    ProceduralDistributions.list['GiftStoreToys'].items,
    ProceduralDistributions.list['GigamartToys'].items,
    ProceduralDistributions.list['Hobbies'].items,
    ProceduralDistributions.list['HolidayStuff'].items,
    ProceduralDistributions.list['SpiffosKitchenSpecial'].items,
    ProceduralDistributions.list['WardrobeChild'].items,

    VehicleDistributions.SpiffoTruckBed.items,
    VehicleDistributions.SpiffoSeatFront.items,
    VehicleDistributions.EvacueeSeatFront.items,
    VehicleDistributions.EvacueeSeatRear.items,
}

module.targetStoryClutters = {
    StoryClutter.KidClutter,
    StoryClutter.PillowClutter,
}


-- add to distrubitions
for i = 1, #module.targetDistributions do
    local dist = module.targetDistributions[i]
    
    -- find the weight of target source
    local weight
    for j = 1, #dist, 2 do
        print(dist[j], dist[j + 1])
        if dist[j] == module.TARGET_SOURCE then
            weight = dist[j + 1]
            break
        end
    end

    -- add the plushie at the end with its weight
    if weight then
        print('HorseMod: Adding ' .. module.TO_ADD .. ' to distribution with weight ' .. tostring(weight))
        dist[#dist + 1] = module.TO_ADD
        dist[#dist + 1] = weight
    end
end


-- simply add to clutters
for i = 1, #module.targetStoryClutters do
    local clutter = module.targetStoryClutters[i]
    clutter[#clutter + 1] = module.TO_ADD
end


-- add to foraging
forageSystem.addForageDef(
    module.TARGET_SOURCE,
    {
        type = module.TARGET_SOURCE,
        xp = 10,
        categories	= { 'Junk', 'Trash' },
        zones = {
            Forest = 3,
            DeepForest = 3,
            PHForest = 3,
            PRForest = 3,
            BirchForest = 3,
            OrganicForest = 3,
            Vegitation = 3,
            FarmLand = 3,
            TrailerPark = 3,
            TownZone = 3,
            ForagingNav = 3,
        },
        spawnFuncs = { forageSystem.doGenericItemSpawn },
        forceOutside = false,
        canBeAboveFloor = true,
        itemSizeModifier = 0.5,
        isItemOverrideSize = true,
    }
)