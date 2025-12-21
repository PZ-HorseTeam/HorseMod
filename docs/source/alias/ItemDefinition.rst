ItemDefinition
==============

.. lua:autoalias:: HorseMod.ItemDefinition

Example
-------

::

    ---@type ItemDefinition
    local exampleItemDefinitions = {
        ["Saddle"] = {
            equipBehavior = {
                time = -1,
                anim = {
                    ["Left"] = "Horse_EquipSaddle_Left",
                    ["Right"] = "Horse_EquipSaddle_Right",
                },
                shouldHold = true,
            },
        },
    }