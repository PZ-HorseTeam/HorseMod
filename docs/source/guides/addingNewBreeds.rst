Adding new breeds
=================
It is possible to add new breeds to the mod, you will simply need texture variants for the new breed, and if you want, you can also add leather variants, saddle variants etc.

Defining the new breed
----------------------

Pick a unique ID for the horse and add it to the :lua:obj:`HorseMod.definitions.HorseDefinitions.SHORT_NAMES` table:

.. code::

    local HorseDefinitions = require("HorseMod/definitions/HorseDefinitions")

    table.insert(HorseDefinitions.SHORT_NAMES, "YourVeryUniqueBreedID")

This ID will be used to identify the texture files of your horse and will be formatted automatically for each entries of :lua:obj:`HorseMod.definitions.HorseDefinitions.PATHS`.

add link to https://pzwiki.net/wiki/AnimalDefinitions

By using this system, you assure yourself that your horse breed will use the same stats as our horses. If you want to add your breed with specific stats, we suggest that you check out the `AnimalDefinitions wiki page <https://pzwiki.net/wiki/AnimalDefinitions>`_ to better understand what stats are available and how they are defined. In your case, you will be interested in defining a new `breed <https://pzwiki.net/wiki/AnimalDefinitions#Breeds>`_ to insert in `AnimalDefinitions.breeds['Horse'].breeds`.

You can use the automatic system to use all the default stats of horses, and then modify individually the stats in the table you want to modify. This is useful for `forced genes <https://pzwiki.net/wiki/AnimalDefinitions#breed_forcedGenes>`_ for specific breeds for example.

.. code::

    -- you need to make sure that the Horse mod is loaded first before you can access the breed data
    Events.OnGameBoot.Add(function()
        local breedData = AnimalDefinitions.breeds['Horse'].breeds['YourVeryUniqueBreedID']
        breedData.minWeight = 500
        breedData.maxWeight = 2000
        
        -- you can force specific gene values, if you add a horse with specific real world stats
        breedData.forcedGenes = {
            speed = {
                minValue = 1.2, maxValue = 2.0
            },
            stamina = {
                minValue = 0.5, maxValue = 1.0
            },
        }
    end)

Horse textures
--------------

You need to create the following textures for your new breed:
    `media/textures/Body/HorseMod/Horse_YourVeryUniqueBreedID.png`

    `media/textures/Body/HorseMod/Horse_YourVeryUniqueBreedID_Rotting.png`

    `media/textures/Item_body/Horse_YourVeryUniqueBreedID_Foal.png`

    `media/textures/Item_body/Horse_YourVeryUniqueBreedID_Dead.png`

    `media/textures/Item_body/Horse_YourVeryUniqueBreedID_Foal_Dead.png`

Patching recipes to use your new leather
----------------------------------------

You can patch the vanilla recipes for cutting the leather in half using our patch system :lua:obj:`HorseMod.patches.LeatherRecipes`. Simply add your leather full type to the :lua:obj:`HorseMod.patches.LeatherRecipes.LEATHERS` table.

.. code::

    local LeatherRecipes = require("HorseMod/patches/LeatherRecipes")

    --Note the leather items don't have to strictly follow this naming convention here
    --for the full type. We're simply using the same as the vanilla one
    table.insert(LeatherRecipes.LEATHERS, "HorseMod.Leather_YourVeryUniqueBreedID_Fur_Tan")
    table.insert(LeatherRecipes.LEATHERS, "HorseMod.Leather_YourVeryUniqueBreedID_Fur_Tan_Medium")
