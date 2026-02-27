Adding horse spawnpoints
========================

Horses spawn wherever there is a horse zone which can be added using the ::lua:obj:`HorseMod.HorseZones` module. To do so, a ::lua:obj:`HorseMod.HorseZone` object is defined by providing coordinates of a rectangular area via the coordinates of two corners of the rectangle, and a Z level. You can also chose between three different spawn chances with the parameter ::lua:obj:`HorseMod.HorseZones.name`, with the default being `horsesmall`.

The available horse ranch zones are:
- `horsesmall`
- `horsemedium`
- `horselarge`

.. note:: You need to add zones from a Lua file inside `media/lua/server`. since horse zones need to be loaded on both the client and the server and loaded when loading a save.

.. note:: See the `Ranch zone wiki page <https://pzwiki.net/wiki/Ranch_zone>`_ for more detail on what these ranch zones are. Do note that in our case we use a helper function to determine manually the top corner coordinates and the width and height of the zone for ease of use.


Creating a new ranch zone type
------------------------------

It is possible to create a new ranch zone types of the horse:

.. code::

    RanchZoneDefinitions.type["yourVeryUniqueCustomRanchZoneType"] = {
        type = "yourVeryUniqueCustomRanchZoneType", -- change the ID here
        globalName = "horse", -- defines the animal type
        
        -- that chance value is really weird, it's a weight and not a chance
        -- and it's unclear if that actually impacts animal spawn chance
        -- setting to a high value doesn't make sure horses spawn
        chance = 5,

        -- grow stage for male/female
        femaleType = "mare",
        maleType = "stallion",
        
        -- minimum and maximum number male female horses that can spawn in the zone
        minFemaleNb = 0,
        maxFemaleNb = 2,
        minMaleNb = 0,
        maxMaleNb = 2,
        
        chanceForBaby = 5, -- filly and foal chance
        maleChance = 50 -- proportion of male/female chance to spawn
    }

Adding a new zone from WorldEd
------------------------------

Create a new zone of type `Ranch` and for the `name` field, use the available horse ranch zones or your own custom one.

Adding a new zone from Lua
--------------------------

.. code::

    local HorseZones = require("HorseZones")

    table.insert(
        HorseZones.zones,
        {
            x1 = 5546,
            y1 = 6505,
            x2 = 5617,
            y2 = 6514,
            z = 0,
        }
    )

    table.insert(
        HorseZones.zones,
        {
            x1 = 5546,
            y1 = 6505,
            x2 = 5617,
            y2 = 6514,
            z = 0,
            name = "horselarge",
        }
    )

    table.insert(
        HorseZones.zones,
        {
            x1 = 5546,
            y1 = 6505,
            x2 = 5617,
            y2 = 6514,
            z = 0,
            name = "yourVeryUniqueCustomRanchZoneType",
        }
    )
