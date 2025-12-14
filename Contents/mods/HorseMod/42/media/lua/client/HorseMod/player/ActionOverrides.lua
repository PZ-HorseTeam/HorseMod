local HorseRiding = require("HorseMod/Riding")
local Attachments = require("HorseMod/attachments/Attachments")
local ContainerManager = require("HorseMod/attachments/ContainerManager")
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

---Find if the given world item is a valid horse attachment container for the given horse and if it can be accessed from mount.
local function isValidHorseContainer(worldItem, horse)
    -- check if the world item is a horse mod container
    local containerInfo = ContainerManager.getHorseContainerData(worldItem)
    if not containerInfo then return false end
    
    -- check if the container is from the horse
    if containerInfo.horseID ~= horse:getAnimalID() then return false end

    -- check if it can't be accessed by the player from mount
    local slot = containerInfo.slot
    local fullType = containerInfo.fullType
    local attachmentDef = Attachments.getAttachmentDefinition(fullType, slot)
    if attachmentDef and attachmentDef.notReachableFromMount then
        return false
    end

    return true
end

---Verify if a source container is valid for transfer while mounted on a horse. The source must be the player inventory, a container the player is holding or a horse attachment container on the mounted horse which can be accessed from mount.
---@param srcContainer ItemContainer
---@param character IsoPlayer
---@param horse IsoAnimal
local function isValidSource(srcContainer, character, horse)
    -- if source container is the player inventory allow
    local parent = srcContainer:getParent()
    if parent and parent == character then
        return true
    end

    -- access the InventoryItem item, if nil it's the ground itself
    local containerItem = srcContainer:getContainingItem()
    if not containerItem then return false end

    -- access the world item
    local worldItem = containerItem:getWorldItem()
    if not worldItem then
        -- verify if the item is in the player inventory
        local playerInventory = character:getInventory()
        if playerInventory:containsRecursive(containerItem) then
            return true
        end

        return false
    end

    if not isValidHorseContainer(worldItem, horse) then
        return false
    end

    return true
end

---Verify if a destination container is valid for transfer while mounted on a horse. The destination must be rechable from mount, so either in the player inventory, a container the player is holding or a horse attachment container on the mounted horse which can be accessed from mount. It can also be the ground but it cannot be a container on the ground since the player can't reach it from mount.
---@param destContainer ItemContainer
---@param character IsoPlayer
---@param horse IsoAnimal
local function isValidDestination(destContainer, character, horse)
    -- if source container is the player inventory allow
    local parent = destContainer:getParent()
    if parent and parent == character then
        return true
    end

    -- access the InventoryItem item, if nil it's the ground itself
    local containerItem = destContainer:getContainingItem()
    if not containerItem then return true end

    -- access the world item, if no world item, it's on the ground
    local worldItem = containerItem:getWorldItem()
    if not worldItem then return true end

    if isValidHorseContainer(worldItem, horse) then
        return true
    end

    return false
end


-- Allow all transfers if Inventory Tetris is active since it alters transfer action behavior
local invTetris = getActivatedMods():contains("\\INVENTORY_TETRIS")

local _originalIsValidTransfer = ISInventoryTransferAction.isValid

function ISInventoryTransferAction:isValid()
    if invTetris then
        return _originalIsValidTransfer(self)
    end

    -- if the player is mounting a horse, it cannot access certain containers to transfer items from/to
    local horse = HorseRiding.getMountedHorse(self.character)
    if horse then
        local srcContainer = self.srcContainer
        local destContainer = self.destContainer
        local character = self.character

        -- verify source and destination containers are valid while mounted
        local checkSrc = isValidSource(srcContainer, character, horse)
        local checkDest = isValidDestination(destContainer, character, horse)
        if not checkSrc or not checkDest then
            return false
        end
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
