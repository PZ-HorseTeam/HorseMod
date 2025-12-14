ContainerManager
================
This module handles the management of containers associated with horse attachments that have container behavior, such as saddlebags.

It is used to create an invisible world item container defined via the :lua:class:`HorseMod.ContainerBehavior` component when an attachment is equipped on a horse, and to manage the transfer of items between the attachment's inventory item and this invisible world item container.

When the attachment is added to a horse, the attachment container will disappear and its content will be moved to that invisible container. When the attachment is removed from the horse, a fresh container is created if the original one is now unavailable (after reloading the area for example) and the items are moved back from the invisible container to the attachment InventoryItem, and this invisible world item container is deleted.

When reloading an area, the invisible container might be lost, so the ContainerManager searches for it by using previously known information and the current known position of the horse.

:lua:class:`HorseMod.ContainerInformation` is used to store necessary data about the container, including the world item reference and its position in the mod data of the invisible world item container as well as in the :lua:class:`HorseMod.HorseModData` ``containers`` table.

When trying to locate the container upon reloading an area, first the ContainerManager checks the ``ORPHAN_CONTAINERS`` cache table for the world item ID. Secondly the ContainerManager uses the stored world item XYZ coordinates to search for the container near that position.

Because animals don't seem to move, the ContainerManager then searches for the container at the position of the horse when loading the area.

Alternatively in the future if these checks aren't enough, containers could be retrieved by checking squares of newly loaded chunks for the container attachments world items.

.. lua:automodule:: HorseMod.attachments.ContainerManager
    :members:
    :undoc-members:
