-- gene definitions specific to horses
AnimalGenomeDefinitions.genes["speed"] = {
    minValue = 0.9,
    maxValue = 1.1,
    forcedValues = true,
}

AnimalGenomeDefinitions.genes["stamina"] = {
    -- endurance influences how long a horse can gallop
    minValue = 0.8,
    maxValue = 1.2,
    forcedValues = true,
}

AnimalGenomeDefinitions.genes["carryWeight"] = {
    minValue = 0.85,
    maxValue = 1.25,
    forcedValues = true,
}

AnimalGenomeDefinitions.genes["strength"] = {
    minValue = 0.85,
    maxValue = 1.25,
    forcedValues = true,
}
