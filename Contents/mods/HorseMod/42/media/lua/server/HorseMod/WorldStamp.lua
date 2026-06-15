local STAMP_KEY = "horsemod"

local function onInitGlobalModData(isNewGame)
    local modData = ModData.getOrCreate(STAMP_KEY)

    if modData.newGame == true and modData.worldStamped == nil then
        modData.worldStamped = true
    end

    if isNewGame then
        modData.worldStamped = true
    elseif modData.worldStamped == nil then
        modData.worldStamped = false
    end

    if isClient() then
        return
    elseif isServer() then
        return
    else
        return
    end
end

Events.OnInitGlobalModData.Add(onInitGlobalModData)
