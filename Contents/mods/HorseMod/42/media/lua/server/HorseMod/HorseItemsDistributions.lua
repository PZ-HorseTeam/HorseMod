local table_insert = table.insert

local saddleItems = {
    "HorseMod.HorseSaddle_Crude",
    "HorseMod.HorseSaddle_Black",
    "HorseMod.HorseSaddle_White",
}

local saddlebagItems = {
    "HorseMod.HorseSaddlebags_Crude",
    "HorseMod.HorseSaddlebags_Black",
    "HorseMod.HorseSaddlebags_White",
}

local reinsItems = {
    "HorseMod.HorseReins_Crude",
    "HorseMod.HorseReins_Brown",
    "HorseMod.HorseReins_Black",
    "HorseMod.HorseReins_White",
}

local function addItems(dest, items, weight)
    for i = 1, #items do
        table_insert(dest, items[i])
        table_insert(dest, weight)
    end
end

local HorseItemsDistribution = {
    JockeyLockers = {
        items = {},
    },
    BarnTools = {
        items = {},
    },
    FarmerTools = {
        items = {},
    },
    CampingStoreGear = {
        items = {},
    },
    HuntingLockers = {
        items = {},
    },
    SurvivalGear = {
        items = {},
    },
    CrateCamping = {
        items = {},
    },
    CrateSports = {
        items = {},
    },
    CrateAnimalFeed = {
        items = {},
    },
    CratePetSupplies = {
        items = {},
    },
    SportStoreAccessories = {
        items = {},
    },
    WildWestGeneralStore = {
        items = {},
    },
}

addItems(HorseItemsDistribution.JockeyLockers.items, saddleItems, 0.8)
addItems(HorseItemsDistribution.JockeyLockers.items, saddlebagItems, 0.8)
addItems(HorseItemsDistribution.JockeyLockers.items, reinsItems, 0.8)

addItems(HorseItemsDistribution.BarnTools.items, saddleItems, 0.2)
addItems(HorseItemsDistribution.BarnTools.items, saddlebagItems, 0.2)
addItems(HorseItemsDistribution.BarnTools.items, reinsItems, 0.2)

addItems(HorseItemsDistribution.FarmerTools .items, saddleItems, 0.15)
addItems(HorseItemsDistribution.FarmerTools .items, saddlebagItems, 0.15)
addItems(HorseItemsDistribution.FarmerTools .items, reinsItems, 0.15)

addItems(HorseItemsDistribution.CampingStoreGear.items, saddleItems, 0.2)
addItems(HorseItemsDistribution.CampingStoreGear.items, saddlebagItems, 0.2)
addItems(HorseItemsDistribution.CampingStoreGear.items, reinsItems, 0.2)

addItems(HorseItemsDistribution.HuntingLockers.items, saddleItems, 0.4)
addItems(HorseItemsDistribution.HuntingLockers.items, saddlebagItems, 0.4)
addItems(HorseItemsDistribution.HuntingLockers.items, reinsItems, 0.4)

addItems(HorseItemsDistribution.SurvivalGear.items, saddleItems, 0.2)
addItems(HorseItemsDistribution.SurvivalGear.items, saddlebagItems, 0.2)
addItems(HorseItemsDistribution.SurvivalGear.items, reinsItems, 0.2)

addItems(HorseItemsDistribution.CrateCamping.items, saddleItems, 0.2)
addItems(HorseItemsDistribution.CrateCamping.items, saddlebagItems, 0.2)
addItems(HorseItemsDistribution.CrateCamping.items, reinsItems, 0.2)

addItems(HorseItemsDistribution.CrateSports.items, saddleItems, 0.2)
addItems(HorseItemsDistribution.CrateSports.items, saddlebagItems, 0.2)
addItems(HorseItemsDistribution.CrateSports.items, reinsItems, 0.2)

addItems(HorseItemsDistribution.CrateAnimalFeed .items, saddleItems, 0.25)
addItems(HorseItemsDistribution.CrateAnimalFeed .items, saddlebagItems, 0.25)
addItems(HorseItemsDistribution.CrateAnimalFeed .items, reinsItems, 0.25)

addItems(HorseItemsDistribution.CratePetSupplies .items, saddleItems, 0.3)
addItems(HorseItemsDistribution.CratePetSupplies .items, saddlebagItems, 0.3)
addItems(HorseItemsDistribution.CratePetSupplies .items, reinsItems, 0.3)

addItems(HorseItemsDistribution.SportStoreAccessories.items, saddleItems, 0.5)
addItems(HorseItemsDistribution.SportStoreAccessories.items, saddlebagItems, 0.5)
addItems(HorseItemsDistribution.SportStoreAccessories.items, reinsItems, 0.5)

addItems(HorseItemsDistribution.WildWestGeneralStore.items, saddleItems, 0.25)
addItems(HorseItemsDistribution.WildWestGeneralStore.items, saddlebagItems, 0.25)
addItems(HorseItemsDistribution.WildWestGeneralStore.items, reinsItems, 0.25)

local ProceduralDistributions_list = ProceduralDistributions.list

local function insertInDistribution(distrib)
    for k, v in pairs(distrib) do
        local ProceduralDistributions_list_k = ProceduralDistributions_list[k]
        if ProceduralDistributions_list_k then
            local items = v.items
            local ProceduralDistributions_list_k_items = ProceduralDistributions_list_k.items
            if items and ProceduralDistributions_list_k_items then
                for i = 1, #items do
                    table_insert(ProceduralDistributions_list_k_items, items[i])
                end
            end
        end
    end
end

insertInDistribution(HorseItemsDistribution)
