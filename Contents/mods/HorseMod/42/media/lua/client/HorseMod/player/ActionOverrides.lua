local HorseRiding = require("HorseMod/Riding")

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
