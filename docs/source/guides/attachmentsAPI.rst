Attachments API
===============
Attachments on horses are handled by a bunch of different system spread across multiple modules and classes. The system currently allows you to associate an :lua:alias:`HorseMod.AttachmentSlot` to an `attachment point <https://pzwiki.net/wiki/Attachment_(scripts)>`_ on the horse model and define slots various items can occupy with different caracteristics defined as :lua:class:`HorseMod.AttachmentDefinition`.

AttachmentData
--------------
:lua:obj:`HorseMod.attachments.AttachmentData` is the main module used to define and store all the attachment slots and definitions. It provides functions to add new slots and attachments, as well as tables to store the defined slots and attachments.

.. _attachmentsload-label:

AttachmentsLoad
---------------
The file `server/HorseMod/AttachmentsLoad.lua` is used to load slot definitions in :lua:obj:`HorseMod.attachments.AttachmentData.slotsDefinitions` and generate the various tables used by the attachment system from :lua:class:`HorseMod.SlotDefinition` entries:

* :lua:obj:`HorseMod.attachments.AttachmentData.slots`
* :lua:obj:`HorseMod.attachments.AttachmentData.maneSlots`
* :lua:obj:`HorseMod.attachments.AttachmentData.containerItems`

It will also verify that the provided attachments are of the right format and log errors if not:

* Checks that every slot definition has a :lua:obj:`HorseMod.SlotDefinition.modelAttachment` point defined.
* Creates the apparel location in the ``Animal`` attached locations group for every slot defined.
* If an attachment definition has a :lua:class:`HorseMod.ContainerBehavior`, it checks that the item actually is a container (``ItemType.CONTAINER``). It also verifies that the :lua:obj:`HorseMod.ContainerBehavior.worldItem` invisible container has the same capacity as the accessory item.
* Removes any :lua:alias:`HorseMod.ItemDefinition` entry from :lua:obj:`HorseMod.attachments.AttachmentData.items` that don't contain any attachment definitions.

Mane management
---------------
Manes are a special type of attachment that can be colored and are made of multiple parts attached to different points on the horse model. The mane system is handled by the :lua:obj:`HorseMod.attachments.ManeManager` module, which provides functions to setup and remove manes on horse models. When a horse spawns, its manes configuration and color are automatically setup based on its breed using :lua:obj:`HorseMod.attachments.AttachmentData.maneByBreed`.

In the future, we plan to expand this system by allowing players to customize their horse's mane color and style through in-game actions or items.

Attachment reapplying
---------------------
Attachments need to be reapplied whenever a horse model becomes visible again, which can be checked with ``IsoAnimal:getModel()`` (nil means not visible). This is handled by the :lua:obj:`HorseMod.attachments.AttachmentUpdater` module, which is called every in-game tick but updates only a handful of horses per tick to spread the load over multiple ticks.

It detects whenever there is a change of visibility for horses and only triggers the reapplying process when a horse becomes visible again by using :lua:obj:`HorseMod.attachments.AttachmentUpdater.reapplyFor`. This will simply iterate every attachments stored in the :lua:class:`HorseMod.HorseModData` of the horse and attach back the InventoryItem if it can be found, or creates a fresh one if its reference can't be found, which is usually the case whenever a horse was reloaded and not when it switches between visible and non visible.

This reapply then attaches again the attachment to the horse model using :lua:obj:`HorseMod.attachments.Attachments.setAttachedItem`. If it is a mane, if first setup this mane with the use of :lua:obj:`HorseMod.attachments.ManeManager.setupMane`.

Container managing
------------------
Containers attached on horses need to be accessible by the player while attached to the horse, but the attachment system of the base game loses the item references when those get attached on the horse and as such the containers get deleted and lost. To work around that, the attachment system uses invisible containers spawned in the world which follow the horse around and hold the items instead.

Whenever :lua:class:`HorseMod.HorseEquipGear` is used by the player and the attachment has a :lua:class:`HorseMod.ContainerBehavior`, :lua:obj:`HorseMod.attachments.ContainerManager.initContainer` is called to create the invisible world container and transfer all the content to it. This container receives in its mod data, stored under the ``HorseMod.container`` key, a :lua:class:`HorseMod.ContainerInformation` entry to track which horse and slot it is associated with.

When the player unequips the attachment, :lua:obj:`HorseMod.attachments.ContainerManager.removeContainer` is called to transfer back all the items from the invisible world container to the accessory item and delete the world container.

When the horse is unloaded from the area or the player logs out while having a horse with attachments, the invisible world containers references are removed from the horse attachments so whenever that horse is loaded back, it is forced to find back its containers.

When it comes to tracking the containers, :lua:obj:`HorseMod.attachments.ContainerManager.track` is called for every horses from the :lua:obj:`HorseMod.attachments.AttachmentUpdater` module. This function checks every containers on the horse.

If the container world item reference is found, and is on a different square than the horse, it removes this world item and uses its `InventoryItem` instance to create a new invisible world container on the new square. This is needed because we can't directly move world items between squares.

If the container world item reference is missing, we need to find back the invisible world container. To do so, we search for different possibilities:

1. Check the :lua:obj:`HorseMod.attachments.ContainerManager.ORPHAN_CONTAINERS` cache table for the world item ID. 
   
  1. If it is found, we verify that this container is in fact our container by checking its mod data. If it is our container, we remove it from the cache.
  2. If it isn't our container (which it shouldn't happen normally), we verify it is a horse container and update its item ID in the cache. 
  3. If it isn't a horse container, we remove it from the cache and continue searching.
   
2. Use the stored world item XYZ coordinates to search for the container near that position. 
  
  1. If a container is found, we verify it is our container by checking its ID.
  2. If it isn't our container, we verify it is a horse container and cache it as orphaned.
   
3. Because animals don't seem move when unloaded, we search for the container at the position of the horse when loading the area. 
  
  1. If a container is found, we verify it is our container by checking its ID.
  2. If it isn't our container, we verify it is a horse container and cache it as orphaned.

Alternatively in the future if these checks aren't enough, containers could be retrieved by checking squares of newly loaded chunks for the container attachments world items.

Whenever a container is found, its reference is reattached to the :lua:class:`HorseMod.ContainerInformation` of the horse attachment.