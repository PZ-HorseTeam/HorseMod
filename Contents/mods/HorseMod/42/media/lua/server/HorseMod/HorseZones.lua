---@namespace horse


---Horse spawn region.
---@class HorseZone
---
---Min world X coordinate.
---@field x integer
---
---Min world Y coordinate.
---@field y integer
---
---World Z level of the zone.
---@field z integer
---
---Span across the X axis in squares.
---@field width integer
---
---Span across the Y axis in squares.
---@field height integer


RanchZoneDefinitions.type["horse"] = {
    type = "horse",
    globalName = "horse",
    chance = 5,
    femaleType = "mare",
    maleType = "stallion",
    -- TODO: these values are high for testing
    --  as per discord dicussion, stables probably shouldn't even guarantee a horse
    --  it may not actually be possible with the ranch system to make them rare enough...?
    minFemaleNb = 1,
    maxFemaleNb = 2,
    minMaleNb = 1,
    maxMaleNb = 2,
    forcedBreed = nil,
    chanceForBaby = 15,
    maleChance = 50
}

---Creates and manages horse spawn zones e.g. stables.
local HorseZones = {}


---Horse zones to be created.
---@type HorseZone[]
HorseZones.zones = {
    -- riverside country club
    {
        x = 5546, y = 6505, z = 0,
        width = 71, height = 9
    },
    {
        x = 5551, y = 6585, z = 0,
        width = 75, height = 9
    }
}


local function addHorseZones()
    DebugLog.log("HorseMod: creating horse zones")

    local world = getWorld()

    local zonesFailed = 0
    for i = 1, #HorseZones.zones do
        local zoneDef = HorseZones.zones[i]

        local zone = world:registerZone(
            "horse", "Ranch",
            zoneDef.x, zoneDef.y, zoneDef.z,
            zoneDef.width, zoneDef.height
        )
        if zone == nil then
            DebugLog.log(
                string.format(
                    "HorseMod: failed to create horse zone at %d,%d,%d",
                    zoneDef.x, zoneDef.y, zoneDef.z
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