---@namespace horse


---Horse spawn region.
---@class HorseZone
---
---Coordinate X number 1.
---@field x1 integer
---
---Coordinate Y number 2.
---@field y1 integer
---
---Coordinates X number 2.
---@field x2 integer
---
---Coordinates Y number 2.
---@field y2 integer
---
---World Z level of the zone.
---@field z integer?
---
---Name of the `RanchZoneDefinitions` type to use. Can be `horsesmall`, `horsemedium`, or `horselarge` (or any other animal ranch zone types technically). Defaults to `horsesmall`.
---@field name ("horsesmall" | "horsemedium" | "horselarge")?

RanchZoneDefinitions.type["horsesmall"] = {
    type = "horsesmall",
    globalName = "horse",
    chance = 5,
    femaleType = "mare",
    maleType = "stallion",
    minFemaleNb = 0,
    maxFemaleNb = 2,
    minMaleNb = 0,
    maxMaleNb = 2,
    chanceForBaby = 5,
    maleChance = 50
}
RanchZoneDefinitions.type["horsemedium"] = {
    type = "horsemedium",
    globalName = "horse",
    chance = 5,
    femaleType = "mare",
    maleType = "stallion",
    minFemaleNb = 1,
    maxFemaleNb = 2,
    minMaleNb = 1,
    maxMaleNb = 2,
    chanceForBaby = 5,
    maleChance = 50
}
RanchZoneDefinitions.type["horselarge"] = {
    type = "horselarge",
    globalName = "horse",
    chance = 5,
    femaleType = "mare",
    maleType = "stallion",
    minFemaleNb = 1,
    maxFemaleNb = 3,
    minMaleNb = 1,
    maxMaleNb = 3,
    chanceForBaby = 5,
    maleChance = 50
}

local DEFAULT_HORSE_ZONE = "horsesmall"

---Creates and manages horse spawn zones e.g. stables.
local HorseZones = {}


---Horse zones to be created.
---@type HorseZone[]
HorseZones.zones = {
-- riverside country club: high spawnrate location
    -- bottom stables
    { x1 = 5554, y1 = 6593, x2 = 5580, y2 = 6591, name="horsemedium" },
    { x1 = 5587, y1 = 6593, x2 = 5625, y2 = 6591, name="horsemedium" },
    { x1 = 5554, y1 = 6587, x2 = 5580, y2 = 6585, name="horsemedium" },
    { x1 = 5587, y1 = 6587, x2 = 5625, y2 = 6585, name="horsemedium" },

    -- top stables
    { x1 = 5552, y1 = 6513, x2 = 5581, y2 = 6511, name="horsemedium" },
    { x1 = 5546, y1 = 6513, x2 = 5617, y2 = 6511, name="horsemedium" },
    { x1 = 5552, y1 = 6507, x2 = 5581, y2 = 6505, name="horsemedium" },
    { x1 = 5546, y1 = 6507, x2 = 5617, y2 = 6505, name="horsemedium" },

-- horse fields
    -- middle of Echo Creek, Ekron and Irvington
    { x1 = 2259, y1 = 12456, x2 = 2285, y2 = 12419 },
    { x1 = 2270, y1 = 12253, x2 = 2309, y2 = 12290 },
    { x1 = 2429, y1 = 12376, x2 = 2478, y2 = 12426 },


    { x1 = 1532, y1 = 12110, x2 = 1571, y2 = 12075, name="horsemedium" },

    { x1 = 1601, y1 = 12023, x2 = 1609, y2 = 12017 },

    -- near Irvington
    { x1 = 3007, y1 = 13238, x2 = 3026, y2 = 13245, name="horsemedium" }, 
    { x1 = 3003, y1 = 14268, x2 = 3014, y2 = 14271, name="horsemedium" },
    { x1 = 3690, y1 = 14881, x2 = 3727, y2 = 14909, name="horsemedium" },

    -- near Ekron
    { x1 = 521, y1 = 11784, x2 = 555, y2 = 11752 },
    { x1 = 499, y1 = 11603, x2 = 548, y2 = 11650 },
    { x1 = 610, y1 = 11638, x2 = 651, y2 = 11678 },
    { x1 = 743, y1 = 11596, x2 = 760, y2 = 11631 },
    
    { x1 = 921, y1 = 11290, x2 = 953, y2 = 11262 },
    { x1 = 970, y1 = 11199, x2 = 999, y2 = 11170 },
    { x1 = 983, y1 = 11058, x2 = 947, y2 = 11008 },
    { x1 = 949, y1 = 10891, x2 = 988, y2 = 10855 },

    { x1 = 1537, y1 = 11046, x2 = 1565, y2 = 11011, name="horsemedium" },

    { x1 = 722, y1 = 10786, x2 = 758, y2 = 10748 },
    { x1 = 749, y1 = 10664, x2 = 762, y2 = 10674 },
    { x1 = 745, y1 = 10554, x2 = 779, y2 = 10579 },
    { x1 = 747, y1 = 10165, x2 = 776, y2 = 10135, name="horsemedium" },

    { x1 = 1819, y1 = 9859, x2 = 1837, y2 = 9837 },
    { x1 = 1857, y1 = 9820, x2 = 1888, y2 = 9852 },

    { x1 = 1226, y1 = 9037, x2 = 1243, y2 = 9054 },
    { x1 = 1298, y1 = 9035, x2 = 1288, y2 = 9048 },
    { x1 = 1252, y1 = 9105, x2 = 1265, y2 = 9121 },
    { x1 = 1282, y1 = 9133, x2 = 1304, y2 = 9154 },

    -- near Echo Creek
    { x1 = 3780, y1 = 10935, x2 = 3791, y2 = 10955 },
    { x1 = 3792, y1 = 11065, x2 = 3778, y2 = 11028 },
    { x1 = 3821, y1 = 11005, x2 = 3827, y2 = 11011 },
    

-- stables
    -- middle of Echo Creek, Ekron and Irvington
    { x1 = 2046, y1 = 11638, x2 = 2044, y2 = 11645 },
    { x1 = 2311, y1 = 11890, x2 = 2318, y2 = 11892 },

    { x1 = 1232, y1 = 12025, x2 = 1230, y2 = 12032 },

    { x1 = 1416, y1 = 12368, x2 = 1423, y2 = 12370 },

    { x1 = 1880, y1 = 12468, x2 = 1887, y2 = 12470 },

    { x1 = 3133, y1 = 12188, x2 = 3155, y2 = 12172 },

    -- near Ekron
    { x1 = 1606, y1 = 9037, x2 = 1589, y2 = 9040, name="horselarge" },
    { x1 = 1589, y1 = 9048, x2 = 1606, y2 = 9045, name="horselarge" },
    { x1 = 1589, y1 = 9060, x2 = 1606, y2 = 9063, name="horselarge" },
    { x1 = 1606, y1 = 9068, x2 = 1589, y2 = 9071, name="horselarge" },

    { x1 = 1740, y1 = 10279, x2 = 1747, y2 = 10280 },

    { x1 = 241, y1 = 9839, x2 = 244, y2 = 9822 },
    { x1 = 249, y1 = 9839, x2 = 252, y2 = 9822 },
    { x1 = 1405, y1 = 10290, x2 = 1398, y2 = 10288 },
    
    { x1 = 1398, y1 = 10288, x2 = 1405, y2 = 10290 },

    -- near Brandenburg
    { x1 = 3547, y1 = 8202, x2 = 3554, y2 = 8204 },
    { x1 = 3554, y1 = 8207, x2 = 3547, y2 = 8210 },
    { x1 = 3561, y1 = 8202, x2 = 3568, y2 = 8204 },
    { x1 = 3561, y1 = 8208, x2 = 3598, y2 = 8210 },

    { x1 = 1261, y1 = 7314, x2 = 1273, y2 = 7317 }, -- rich manor

    { x1 = 2416, y1 = 5923, x2 = 2418, y2 = 5916 },

    -- near Irvington
    { x1 = 3694, y1 = 14537, x2 = 3701, y2 = 14539 },

    { x1 = 4390, y1 = 14314, x2 = 4404, y2 = 14293 },
    { x1 = 4349, y1 = 14300, x2 = 4325, y2 = 14283 },

    -- central park stables: high spawnrate location
    { x1 = 13035, y1 = 2813, x2 = 13048, y2 = 2816, name="horsemedium" },
    { x1 = 13029, y1 = 2819, x2 = 13032, y2 = 2834, name="horsemedium" },
    { x1 = 13035, y1 = 2837, x2 = 13050, y2 = 2840, name="horsemedium" },

    { x1 = 13611, y1 = 4722, x2 = 13618, y2 = 4723 }, -- near Valley Station

    -- near Fallas Lake
    { x1 = 8553, y1 = 8523, x2 = 8551, y2 = 8518 },

    { x1 = 7130, y1 = 9560, x2 = 7137, y2 = 9562 },
    { x1 = 7142, y1 = 9560, x2 = 7149, y2 = 9561 },
    { x1 = 7132, y1 = 9578, x2 = 7130, y2 = 9573 },

    { x1 = 7089, y1 = 9095, x2 = 7103, y2 = 9098 },
    { x1 = 7108, y1 = 9098, x2 = 7122, y2 = 9096 },

    { x1 = 8622, y1 = 8882, x2 = 8636, y2 = 8879 },
    { x1 = 8600, y1 = 8876, x2 = 8607, y2 = 8878 },

    { x1 = 8852, y1 = 9139, x2 = 8854, y2 = 9132 },

    { x1 = 9258, y1 = 7724, x2 = 9265, y2 = 7726 },

    -- near Muldraugh
    { x1 = 10469, y1 = 10121, x2 = 10476, y2 = 10123 },

    { x1 = 12400, y1 = 9014, x2 = 12411, y2 = 9026 },

    -- near Valley Station
    { x1 = 14296, y1 = 4921, x2 = 14303, y2 = 4923 },

    { x1 = 13911, y1 = 4771, x2 = 13931, y2 = 4753 },

    -- near Echo Creek
    { x1 = 4058, y1 = 10106, x2 = 4065, y2 = 10108 },

    { x1 = 2409, y1 = 10047, x2 = 2416, y2 = 10049 },

    -- lake near Rosewood
    { x1 = 7854, y1 = 14320, x2 = 7863, y2 = 14318 },

    -- near Riverside
    { x1 = 7347, y1 = 6184, x2 = 7354, y2 = 6186 },
    
-- farmer's market
    { x1 = 13707, y1 = 3634, x2 = 13722, y2 = 3623 },


-- LV horsetracks stables: this is a spawnrate location, and one of the only place to get horses in LV
    { x1 = 12334, y1 = 2793, x2 = 12338, y2 = 2775, name="horselarge" },
    { x1 = 12334, y1 = 2760, x2 = 12338, y2 = 2742, name="horselarge" },
    { x1 = 12356, y1 = 2754, x2 = 12364, y2 = 2757 },
    { x1 = 12356, y1 = 2766, x2 = 12364, y2 = 2769 },
    { x1 = 12356, y1 = 2775, x2 = 12364, y2 = 2778 },
    { x1 = 12356, y1 = 2787, x2 = 12364, y2 = 2790 },
}


local function addHorseZones()
    DebugLog.log("HorseMod: creating horse zones")

    local world = getWorld()

    local zonesFailed = 0
    for i = 1, #HorseZones.zones do
        local zoneDef = HorseZones.zones[i]

        -- the top corner (-X,-Y) is the main coordinate point
        -- so we identify it easily from any two given corners
        local x1, y1 = zoneDef.x1, zoneDef.y1
        local x2, y2 = zoneDef.x2, zoneDef.y2
        local main_x = x1 < x2 and x1 or x2
        local main_y = y1 < y2 and y1 or y2

        -- calculate width (+X) and height (+Y)
        local width = math.abs(x2 - x1) + 1
        local height = math.abs(y2 - y1) + 1

        local z = zoneDef.z or 0
        local name = zoneDef.name or DEFAULT_HORSE_ZONE

        local zone = world:registerZone(
            name, "Ranch",
            main_x, main_y, z,
            width, height
        )
        if zone == nil then
            DebugLog.log(
                string.format(
                    "HorseMod: failed to create horse zone at %d,%d,%d",
                    main_x, main_y, z
                )
            )
            zonesFailed = zonesFailed + 1
        end
    end

    if getDebug() and zonesFailed > 0 then
        error(
            string.format("Failed to create %d horse zones", zonesFailed)
        )
    end
end

Events.OnLoadMapZones.Add(addHorseZones)


return HorseZones