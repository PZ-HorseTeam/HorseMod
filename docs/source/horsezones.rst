Adding horse spawnpoints
========================

Horses spawn wherever there is a horse zone. Horse zones can be added using the HorseZones module.
Horse zones must be rectangular, and are defined by the coordinates of their northwest corner and their dimensions.


.. note:: Horse zones must be added before the map has loaded.


.. lua:autoclass:: horse.HorseZone
    :members:

Example
-------
.. code::

    local HorseZones = require("HorseZones")

    table.insert(
        HorseZones.zones,
        {
            x = 5546,
            y = 6505,
            z = 0,
            width = 71,
            height = 9
        }
    )
