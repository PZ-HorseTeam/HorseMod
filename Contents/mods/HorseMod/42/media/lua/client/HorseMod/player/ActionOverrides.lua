local HorseRiding = require("HorseMod/Riding")
require "BuildingObjects/ISBuildingObject"

--------------------------------
---- BLOCK EQUIP/UNEQUIP BELOW BELT ----
--------------------------------

local blockedLocations = {
    UnderwearBottom = true,
    Underwear = true,
    UnderwearExtra1 = true,
    UnderwearExtra2 = true,
    Torso1Legs1 = true,
    Calf_Left_Texture = true,
    Calf_Right_Texture = true,
    Socks = true,
    Legs1 = true,
    Shoes = true,
    Codpiece = true,
    ShortsShort = true,
    ShortPants = true,
    Pants_Skinny = true,
    Gaiter_Right = true,
    Gaiter_Left = true,
    Pants = true,
    Skirt = true,
    Dress = true,
    LongSkirt = true,
    LongDress = true,
    BodyCostume = true,
    PantsExtra = true,
    FullSuit = true,
    Boilersuit = true,
    Knee_Left = true,
    Knee_Right = true,
    Calf_Left = true,
    Calf_Right = true,
    Thigh_Left = true,
    Thigh_Right = true,
    FullRobe = true,
}

local _originalWearClothingValid = ISWearClothing.isValid

function ISWearClothing:isValid()
    if self.item then
        if HorseRiding.getMountedHorse(self.character) then
            local location = self.item:getBodyLocation()
            if location and blockedLocations[location] then
                return false
            end
        end
    end
    return _originalWearClothingValid(self)
end

local _originalUnequipValid = ISUnequipAction.isValid

function ISUnequipAction:isValid()
    if self.item then
        if HorseRiding.getMountedHorse(self.character) then
            local location = self.item:getBodyLocation()
            if location and blockedLocations[location] then
                return false
            end
        end
    end
    return _originalUnequipValid(self)
end

-------------------------------
---- BLOCK TRANSFER ACTION ----
-------------------------------

-- Allow all transfers if Inventory Tetris is active since it alters transfer action behavior
local invTetris = getActivatedMods():contains("\\INVENTORY_TETRIS")

local _originalIsValidTransfer = ISInventoryTransferAction.isValid

function ISInventoryTransferAction:isValid()
    if invTetris then
        return _originalIsValidTransfer(self)
    end
    if HorseRiding.getMountedHorse(self.character)
      and self.srcContainer:getType() == "floor" then
        return false
    end
    return _originalIsValidTransfer(self)
end

-----------------------------
---- BLOCK TIMED ACTIONS ----
-----------------------------

local actions = {
    "AddChumToWaterAction",
    "CreateChumFromGroundSandAction",
    "ISActivateCarBatteryChargerAction",
    "ISActivateGenerator",
    "ISAddAnimalInTrailer",
    "ISAddBaitToFishNetAction",
    "ISAddCompost",
    "ISAddFuel",
    "ISAddSheetAction",
    "ISAddSheetRope",
    "ISBBQAddFuel",
    "ISBBQExtinguish",
    "ISBBQInsertPropaneTank",
    "ISBBQLightFromKindle",
    "ISBBQLightFromLiterature",
    "ISBBQLightFromPetrol",
    "ISBBQRemovePropaneTank",
    "ISBBQToggle",
    "ISBarricadeAction",
    "ISBurnCorpseAction",
    "ISBuryCorpse",
    "ISButcherAnimal",
    "ISCheckFishingNetAction",
    "ISChopTreeAction",
    "ISCleanBurn",
    "ISCleanGraffiti",
    "ISClearAshes",
    "ISConnectCarBatteryToChargerAction",
    "ISCutAnimalOnHook",
    "ISDestroyStuffAction",
    "ISDropCorpseAction",
    "ISEmptyRainBarrelAction",
    "ISEquipHeavyItem",
    "ISFeedAnimalFromHand",
    "ISFillGrave",
    "ISFireplaceAddFuel",
    "ISFireplaceExtinguish",
    "ISFireplaceLightFromKindle",
    "ISFireplaceLightFromLiterature",
    "ISFireplaceLightFromPetrol",
    "ISFitnessAction",
    "ISFixGenerator",
    "ISFixVehiclePartAction",
    "ISGatherBloodFromAnimal",
    "ISGetAnimalBones",
    "ISGetCompost",
    "ISGetOnBedAction",
    "ISGiveWaterToAnimal",
    "ISGrabCorpseAction",
    "ISHutchCleanFloor",
    "ISHutchCleanNest",
    "ISHutchGrabAnimal",
    "ISHutchGrabCorpseAction",
    "ISHutchGrabEgg",
    "ISKillAnimal",
    "ISLightActions",
    "ISLockDoor",
    "ISLureAnimal",
    "ISMilkAnimal",
    "ISOpenButcherHookUI",
    "ISPadlockAction",
    "ISPadlockByCodeAction",
    "ISPickAxeGroundCoverItem",
    "ISPickUpGroundCoverItem",
    "ISPickupAnimal",
    "ISPickupBrokenGlass",
    "ISPickupDung",
    "ISPickupFishAction",
    "ISPlaceCarBatteryChargerAction",
    "ISPlaceTrap",
    "ISPlugGenerator",
    "ISPlumbItem",
    "ISPutAnimalInHutch",
    "ISPutAnimalOnHook",
    "ISPutOutFire",
    "ISRemoveAnimalFromHook",
    "ISRemoveAnimalFromTrailer",
    "ISRemoveBrokenGlass",
    "ISRemoveBush",
    "ISRemoveCarBatteryFromChargerAction",
    "ISRemoveGlass",
    "ISRemoveGrass",
    "ISRemoveHeadFromAnimal",
    "ISRemoveLeatherFromAnimal",
    "ISRemoveMeatFromAnimal",
    "ISRemoveSheetAction",
    "ISRemoveSheetRope",
    "ISRestAction",
    "ISScything",
    "ISSetComboWasherDryerMode",
    "ISShearAnimal",
    "ISSitOnChairAction",
    "ISSitOnGround",
    "ISSmashWindow",
    "ISSplint",
    "ISStitch",
    "ISTakeCarBatteryChargerAction",
    "ISTakeFuel",
    "ISTakeGenerator",
    "ISTakeTrap",
    "ISTakeWaterAction",
    "ISToggleClothingDryer",
    "ISToggleClothingWasher",
    "ISToggleComboWasherDryer",
    "ISToggleHutchDoor",
    "ISToggleHutchEggHatchDoor",
    "ISToggleStoveAction",
    "ISUnbarricadeAction",
    "ISWashClothing",
    "ISWashYourself",
}

local function blockAction(name)
    local action = _G[name]
    if not (action and action.isValid) then return end
    local original = action.isValid
    action.isValid = function(self, ...)
        if HorseRiding.getMountedHorse(self.character) then
            return false
        end
        return original(self, ...)
    end
end

for i=1, #actions do
    local name = actions[i]
    blockAction(name)
end

------------------------
---- BLOCK BUILDING ----
------------------------

local _originalBuildingIsValid

local function initOnStart()

    _originalBuildingIsValid = ISBuildIsoEntity.isValid

    function ISBuildIsoEntity:isValid(square)
        if HorseRiding.getMountedHorse(self.character) then
            return false
        end

        return _originalBuildingIsValid(self, square)
    end
end

Events.OnGameStart.Add(initOnStart)

-------------------------------------
---- BLOCK CRAFTING WITH SURFACE ----
-------------------------------------

local _originalHandCraftValid = ISHandcraftAction.isValid

function ISHandcraftAction:isValid()
    if HorseRiding.getMountedHorse(self.character) and self.craftBench then
        return false
    end
    return _originalHandCraftValid(self)
end
