local HorseUtils  = require("HorseMod/HorseUtils")
local HorseRiding = require("HorseMod/HorseRiding")
local dbg = require("HorseMod/HorseAttachDebug")

local function doHorseInteractionMenu(context, player, animal)
    if not animal or not HorseUtils.isHorse(animal) then return end
    if HorseRiding.canMountHorse(player, animal) then
        -- FIXME: currently we set this variable here because animations are still in testing
        -- we should detect when a horse spawns and apply this immediately
        animal:setVariable("isHorse", true)
        context:addOption(getText("IGUI_HorseMod_MountHorse"),
                          player, HorseRiding.mountHorse, animal)
    end
end

local function onClickedAnimalForContext(playerNum, context, animals, test)
    if test then return end
    if not animals or #animals == 0 then return end
    doHorseInteractionMenu(context, getSpecificPlayer(playerNum), animals[1])
end

local function addFeedHorseOption(playerNum, context, animals, test)
    local horse = animals[1]
    local player = getSpecificPlayer(playerNum)
    local items = horse:getAllPossibleFoodFromInv(player)
    if not items or items:isEmpty() then return end
    local root = context:addOption(getText("IGUI_Feed_Horse"))
    local sub  = ISContextMenu:getNew(context)
    local item = instanceItem("Base.Bag_BigHikingBag")
    HorseMod.attachBackpack(horse, item)
    context:addSubMenu(root, sub)
    for i=0,items:size()-1 do
        local it = items:get(i)
        sub:addOption(it:getDisplayName(), player, function(p, a, item)
        if luautils.walkAdj(p, a:getSquare()) then
            a:eatFromLured(p, item)
        end
        end, horse, it)
    end
end

Events.OnClickedAnimalForContext.Add(onClickedAnimalForContext)
Events.OnClickedAnimalForContext.Add(addFeedHorseOption)