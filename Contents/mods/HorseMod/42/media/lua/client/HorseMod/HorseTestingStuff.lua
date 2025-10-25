local HorseBridleModel = {}
local HorseRiding = require("HorseMod/Riding")

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

local function onKeyPressed(key)
    local player = getSpecificPlayer(0)
    -- local mountedHorse = HorseRiding.getMountedHorse(player)
    -- if not mountedHorse then return end
    -- local bridleItem = findHorseBridle(mountedHorse)
    if key == Keyboard.KEY_G then
        player:setVariable("swingAnim", true)
        -- if bridleItem then
        --     print("BRIDLE WALKING")
        --     bridleItem:setStaticModel("HorseMod.Horse_BridleWalking")
        --     -- mountedHorse:resetModel()
        --     -- mountedHorse:resetModelNextFrame()
        --     mountedHorse:resetEquippedHandsModels()
        --     -- bridleItem:synchWithVisual()
        -- end
    end
    -- if key == Keyboard.KEY_H then
    --     if bridleItem then
    --         print("BRIDLE RUNNING")
    --         bridleItem:setStaticModel("HorseMod.Horse_BridleRunning")
    --         -- mountedHorse:resetModel()
    --         -- mountedHorse:resetModelNextFrame()
    --         mountedHorse:resetEquippedHandsModels()
    --         -- bridleItem:synchWithVisual()
    --     end
    -- end
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