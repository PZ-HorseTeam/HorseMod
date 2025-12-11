local HorseBridleModel = {}
local HorseRiding = require("HorseMod/Riding")
local HorseManager = require("HorseMod/HorseManager")

local function findHorseBridle(horse)
    if horse.getAttachedItems then
        local items = horse:getAttachedItems()
        if items then
            for i = 0, items:size() - 1 do
                local attached = items:get(i)
                if attached then
                    print("Attached: ", attached)
                    local attachedItem = attached:getItem()
                    if attachedItem:getType() == "HorseBridle" then
                        return attachedItem
                    end
                end
            end
        end
    end
end

local function getClosestHorse(player)
    local closestHorse = nil
    local closestDistanceSquared = math.huge

    for i = 1, #HorseManager.horses do
        local horse = HorseManager.horses[i]
        if horse and horse.isExistInTheWorld and horse:isExistInTheWorld() then
            local distanceSquared = player:DistToSquared(horse:getX(), horse:getY())
            if distanceSquared < closestDistanceSquared then
                closestHorse = horse
                closestDistanceSquared = distanceSquared
            end
        end
    end

    return closestHorse
end

local function onKeyPressed(key)
    local player = getSpecificPlayer(0)
    if not player then
        return
    end

    if key == Keyboard.KEY_G then
        local horse = getClosestHorse(player)
        if horse and horse.getBehavior then
            horse:getBehavior():setBlockMovement(true)
        end
    end
    if key == Keyboard.KEY_H then
        local horse = getClosestHorse(player)
        if horse and horse.getBehavior then
            horse:getBehavior():setBlockMovement(false)
        end
    end
end

Events.OnKeyPressed.Add(onKeyPressed)

-- local function initOnStart()

--     loadStaticZomboidModel(
--         "HorseMod.Horse_BridleWalking",
--         "HorseMod/HorseReinsWalking",
--         "Items/HorseReins"
--     )
--     loadStaticZomboidModel(
--         "HorseMod.Horse_BridleRunning",
--         "HorseMod/HorseReinsRunning",
--         "Items/HorseReins"
--     )
-- end

-- Events.OnGameStart.Add(initOnStart)

return HorseBridleModel