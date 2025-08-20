HorseMod = HorseMod or {}

function HorseMod.attachBackpack(animal, backpackItem)
    if not animal or not backpackItem then return end
    local pack = animal:getInventory():AddItem("HorseMod.HorseSaddle")
    -- -- animal:setAttachedItem("bowtie", instanceItem("Base.Animal_BowtieGold"))
    animal:setAttachedItem("Back", pack)
    print("Attached backpack to horse")
    -- local attached = animal:getAttachedItems()
    -- attached:setItem("bowtie", instanceItem("Base.Animal_BowtieGold"))
end

local function reapply(horse)
    -- print("Horse inv: ", horse:getInventory():getItems())
    local item = horse:getInventory():FindAndReturn("HorseMod.HorseSaddle")
    if item then
        horse:setAttachedItem("Back", item)
    end
end

local RADIUS = 20
local tick   = 0

Events.OnTick.Add(function()
    tick = tick + 1
    if tick % 120 ~= 0 then return end

    local player = getPlayer()
    if not player then return end

    local cell = getCell()
    local z    = player:getZ()
    local px   = math.floor(player:getX())
    local py   = math.floor(player:getY())

    for x = px - RADIUS, px + RADIUS do
        for y = py - RADIUS, py + RADIUS do
            local square = cell:getGridSquare(x, y, z)
            if square then
                local animals = square:getAnimals()
                if animals then
                    for i = 0, animals:size() - 1 do
                        local animal = animals:get(i)
                        -- print("animal: ", animal)
                        if animal:isOnScreen() then
                            -- print("Animal on screen")
                            reapply(animal)
                        end
                    end
                end
            end
        end
    end
end)