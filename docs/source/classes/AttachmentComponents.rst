Attachment components
=====================

Attachment components are used to define properties and behaviors of attachment items.

Equip behavior
--------------
This component defines the timed action behavior when equipping an attachment, allowing for custom animations and specifications on the time required to equip or unequip.

For example, the saddle attachment uses this component to specify the animation and time taken to equip it:
::

    equipBehavior = {
        time = -1,
        anim = {
            ["Left"] = "Horse_EquipSaddle_Left",
            ["Right"] = "Horse_EquipSaddle_Right",
        },
        shouldHold = true,
    }

This component can be both used to customize equip and unequip actions for attachments.

.. lua:autoclass:: HorseMod.EquipBehavior
    :members:

--------------

Container behavior
------------------
This component defines the container behavior for attachments that can hold items, such as saddlebags. It defines a world item that represents the container in the game world which will serve as an invisible container in the world that the players can't see but can store item in.

::

    containerBehavior = {
        worldItem = "HorseMod.HorseSaddlebagsContainer",
    }

The majority of this component is handled in the :lua:obj:`HorseMod.attachments.ContainerManager` module, which manages the creation, tracking, and updating of these containers as attachments are equipped and unequipped. 

.. lua:autoclass:: HorseMod.ContainerBehavior
    :members:
