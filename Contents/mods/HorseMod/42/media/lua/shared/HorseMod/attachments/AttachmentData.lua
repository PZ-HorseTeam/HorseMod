---@namespace HorseMod

local HorseUtils = require("HorseMod/Utils")
local Event = require("HorseMod/Event")


---Defines an attachment slot ID, see :ref:`availableslots-label` for the full list of attachment slots.
---@alias AttachmentSlot string


---Used to define a new attachment slot.
---@class SlotDefinition
---
---The model `attachment point <https://pzwiki.net/wiki/Attachment_(scripts)>`_.
---@field modelAttachment string
---
---Whenever this slot is a mane slot. Mane slots are mostly hidden from the player in menus.
---@field isMane boolean?
---
---Default mane item full type this slot will spawn with upon horse creation.
---@field defaultMane string?


---Hex color code (#rrggbb).
---@alias HexColor string



---A mane definition for a horse breed.
---@class ManeDefinition
---
---Hex color code for the mane of the horse.
---@field hex HexColor[]
---
---A mane configuration associated to a horse breed.
---@field maneConfig table<AttachmentSlot, string>



---Equip behavior to use during equip or unequip timed actions for attachments.
---@class EquipBehavior
---
---Time to equip, if `-1` the animation defines the end time.
---@field time number
---
---Animations to play during equip, based on the mounting position, it must be an AnimNode variable condition.
---@field anim {["Left"]: string?, ["Right"]: string?}?
---
---Whenever the item should be held in hand when equipping it. Defaults to `false`.
---@field shouldHold boolean?


---Used to assign container behavior handling to an attachment.
---@class ContainerBehavior
---
---Full type of the item being used as the invisible container.
---@field worldItem string


---Defines an attachment item with its associated slots and extra data if needed.
---@class AttachmentDefinition
---
---Unequip timed action behavior.
---@field unequipBehavior EquipBehavior?
---
---Model script ID to show when attached. Suffixes are used to define different states (e.g. reins during movement).
---@field model string?
---
---Hide the item in menus. [not fully tested]
---@field hidden boolean? 
---
---Container behavior component.
---@field containerBehavior ContainerBehavior?
---
---Equip timed action behavior component.
---@field equipBehavior EquipBehavior? 
---
---Whenever the player can reach from mount this attachment, always considered reachable by default. Notably used for containers.
---@field notReachableFromMount boolean?


---A slots configuration for an InventoryItem full type holding the various configurations the item can take on different slots.
---@alias ItemDefinition table<AttachmentSlot, AttachmentDefinition>


---Stores the various attachment data which are required to work with attachments for horses.
local AttachmentData = {
    ---Maps items' fulltype to their associated attachment definition.
    ---@type table<string, ItemDefinition>
    items = {},

    ---Holds the unique full types of world items for container behaviors.
    ---Automatically generated from :lua:obj:`HorseMod.ContainerBehavior.worldItem`.
    ---@type table<string, true>
    containerItems = {},

    ---Default attachment definitions.
    ---@type table<string, ItemDefinition>
    DEFAULT_ATTACHMENT_DEFS = {
        ---Default saddle attachment definition.
        ---@type ItemDefinition
        SADDLE = {
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
        },

        ---Default saddlebags attachment definition.
        ---@type ItemDefinition
        SADDLEBAGS = {
            ["Saddlebags"] = {
                containerBehavior = {
                    worldItem = "HorseMod.HorseSaddlebagsContainer",
                },
            },
        },

        ---Default tent attachment definition.
        ---@type ItemDefinition
        TENT = { ["Tent"] = {} },

        ---Default sleeping bag attachment definition.
        ---@type ItemDefinition
        SLEEPING_BAG = { ["SleepingBag"] = {} },
    },

    ---Sets attachment model points and mane properties for attachment slots.
    ---!doctype table
    ---@type table<AttachmentSlot, SlotDefinition>
    slotsDefinitions = {
        ---ACCESSORIES
        ["Saddle"] = {modelAttachment="saddle"},
        ["Saddlebags"] = {modelAttachment="saddlebags"},
        ["Tent"] = {modelAttachment="tent"},
        ["SleepingBag"] = {modelAttachment="sleepingBag"},
        ["Head"] = {modelAttachment="head"},
        ["Reins"] = {modelAttachment="reins"},

        ---MOUNTING POINTS
        ["MountLeft"] = {modelAttachment="mountLeft"},
        ["MountRight"] = {modelAttachment="mountRight"},

        ---MANES
        ["ManeStart"] = {
            modelAttachment="maneStart", 
            isMane=true, defaultMane="HorseMod.HorseManeStart"
        },
        ["ManeMid1"] = {
            modelAttachment="maneMid1", 
            isMane=true, defaultMane="HorseMod.HorseManeMid"
        },
        ["ManeMid2"] = {
            modelAttachment="maneMid2", 
            isMane=true, defaultMane="HorseMod.HorseManeMid"
        },
        ["ManeMid3"] = {
            modelAttachment="maneMid3", 
            isMane=true, defaultMane="HorseMod.HorseManeMid"
        },
        ["ManeMid4"] = {
            modelAttachment="maneMid4", 
            isMane=true, defaultMane="HorseMod.HorseManeMid"
        },
        ["ManeMid5"] = {
            modelAttachment="maneMid5", 
            isMane=true, defaultMane="HorseMod.HorseManeMid"
        },
        ["ManeEnd"] = {
            modelAttachment="maneEnd", 
            isMane=true, defaultMane="HorseMod.HorseManeEnd"
        },
    },

    ---Every available attachment slots. 
    ---Automatically generated from :lua:obj:`HorseMod.attachments.AttachmentData.slotsDefinitions`.
    ---@type AttachmentSlot[]
    slots = {},

    ---Mane slots associated to their default mane items.
    ---Automatically generated from :lua:obj:`HorseMod.attachments.AttachmentData.slotsDefinitions`.
    ---@type table<AttachmentSlot, string>
    maneSlots = {},

    ---Breeds associated to their mane colors.
    ---@type table<string, HexColor[]>
    MANE_HEX_BY_BREED = {
        ["AmericanQuarterPalomino"] = {"#EADAB6"},
        ["AmericanQuarterBlueRoan"] = {"#19191C"},
        
        ["AmericanPaintTobiano"] = {"#FBDEA7"},
        ["AmericanPaintOvero"] = {"#292524"},
        
        ["AppaloosaGrullaBlanket"] = {"#24201D"},
        ["AppaloosaLeopard"] = {"#FFF7E4"},
        
        ["ThoroughbredBay"] = {"#140C08"},
        ["ThoroughbredFleaBittenGrey"] = {"#FCECC5"},
    },

    ---Default mane items configuration.
    ---@type ManeDefinition
    MANE_DEFAULT = {
        hex={"#6B5642"},
        maneConfig = {
            ["ManeStart"] = "HorseMod.HorseManeStart",
            ["ManeMid1"] = "HorseMod.HorseManeMid",
            ["ManeMid2"] = "HorseMod.HorseManeMid",
            ["ManeMid3"] = "HorseMod.HorseManeMid",
            ["ManeMid4"] = "HorseMod.HorseManeMid",
            ["ManeMid5"] = "HorseMod.HorseManeMid",
            ["ManeEnd"] = "HorseMod.HorseManeEnd",
        },
    },


    ---Mane definitions by horse breed.
    ---Automatically generated from :lua:obj:`HorseMod.attachments.AttachmentData.MANE_HEX_BY_BREED`.
    ---@type table<string, ManeDefinition>
    maneByBreed = {},

    ---Suffix for rein model swapping during horse riding.
    ---@type table<string, string>
    REIN_STATES = {
        idle = "",
        walking = "_Walking",
        trot = "_Troting",
        gallop = "_Running"
    },
}

local DEFAULT_ATTACHMENT_DEFS = AttachmentData.DEFAULT_ATTACHMENT_DEFS

--- Data holding attachment informations

---@type table<string, ItemDefinition>
AttachmentData.items = {
    -- saddles
        -- vanilla animals
    ["HorseMod.HorseSaddle_Crude"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
    ["HorseMod.HorseSaddle_Black"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
    ["HorseMod.HorseSaddle_CowHolstein"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
    ["HorseMod.HorseSaddle_CowSimmental"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
    ["HorseMod.HorseSaddle_White"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
    ["HorseMod.HorseSaddle_Landrace"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
        -- horses
    ["HorseMod.HorseSaddle_AmericanPaintTobiano"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
    ["HorseMod.HorseSaddle_AmericanPaintOvero"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
    ["HorseMod.HorseSaddle_AmericanQuarterBlueRoan"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
    ["HorseMod.HorseSaddle_AmericanQuarterPalomino"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
    ["HorseMod.HorseSaddle_AppaloosaGrullaBlanket"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
    ["HorseMod.HorseSaddle_AppaloosaLeopard"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
    ["HorseMod.HorseSaddle_ThoroughbredBay"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
    ["HorseMod.HorseSaddle_ThoroughbredFleaBittenGrey"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,

    -- saddlebags
        -- vanilla animals
    ["HorseMod.HorseSaddlebags_Crude"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_Black"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_CowHolstein"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_CowSimmental"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_White"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_Landrace"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
        -- horses
    ["HorseMod.HorseSaddlebags_AmericanPaintTobiano"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_AmericanPaintOvero"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_AmericanQuarterBlueRoan"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_AmericanQuarterPalomino"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_AppaloosaGrullaBlanket"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_AppaloosaLeopard"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_ThoroughbredBay"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_ThoroughbredFleaBittenGrey"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,

    -- reins
    ["HorseMod.HorseReins_Crude"] = { ["Reins"] = {model = "HorseMod.HorseReins_Crude"} },
    ["HorseMod.HorseReins_Black"] = { ["Reins"] = {model = "HorseMod.HorseReins_Black"} },
    ["HorseMod.HorseReins_White"] = { ["Reins"] = {model = "HorseMod.HorseReins_White"} },
    ["HorseMod.HorseReins_Brown"] = { ["Reins"] = {model = "HorseMod.HorseReins_Brown"} },

    -- packing
    ["Base.TentYellow_Packed"] = DEFAULT_ATTACHMENT_DEFS.TENT,
    ["Base.TentBrown_Packed"] = DEFAULT_ATTACHMENT_DEFS.TENT,
    ["Base.TentBlue_Packed"] = DEFAULT_ATTACHMENT_DEFS.TENT,
    ["Base.TentGreen_Packed"] = DEFAULT_ATTACHMENT_DEFS.TENT,
    ["Base.CampingTentKit2_Packed"] = DEFAULT_ATTACHMENT_DEFS.TENT,
    ["Base.ImprovisedTentKit_Packed"] = DEFAULT_ATTACHMENT_DEFS.TENT,
    ["Base.HideTent_Packed"] = DEFAULT_ATTACHMENT_DEFS.TENT,

    ["Base.SleepingBag_Cheap_Green2_Packed"] = DEFAULT_ATTACHMENT_DEFS.SLEEPING_BAG,
    ["Base.SleepingBag_Cheap_Green_Packed"] = DEFAULT_ATTACHMENT_DEFS.SLEEPING_BAG,
    ["Base.SleepingBag_Cheap_Blue_Packed"] = DEFAULT_ATTACHMENT_DEFS.SLEEPING_BAG,
    ["Base.SleepingBag_Hide_Packed"] = DEFAULT_ATTACHMENT_DEFS.SLEEPING_BAG,
    ["Base.SleepingBag_HighQuality_Brown_Packed"] = DEFAULT_ATTACHMENT_DEFS.SLEEPING_BAG,
    ["Base.SleepingBag_RedPlaid_Packed"] = DEFAULT_ATTACHMENT_DEFS.SLEEPING_BAG,
    ["Base.SleepingBag_Camo_Packed"] = DEFAULT_ATTACHMENT_DEFS.SLEEPING_BAG,
    ["Base.SleepingBag_Green_Packed"] = DEFAULT_ATTACHMENT_DEFS.SLEEPING_BAG,
    ["Base.SleepingBag_GreenPlaid_Packed"] = DEFAULT_ATTACHMENT_DEFS.SLEEPING_BAG,
    ["Base.SleepingBag_BluePlaid_Packed"] = DEFAULT_ATTACHMENT_DEFS.SLEEPING_BAG,
    ["Base.SleepingBag_Spiffo_Packed"] = DEFAULT_ATTACHMENT_DEFS.SLEEPING_BAG,

    -- manes
    ["HorseMod.HorseManeStart"] = { ["ManeStart"] = {hidden = true} },
    ["HorseMod.HorseManeMid"]   = {
        ["ManeMid1"] = {hidden = true},
        ["ManeMid2"] = {hidden = true},
        ["ManeMid3"] = {hidden = true},
        ["ManeMid4"] = {hidden = true},
        ["ManeMid5"] = {hidden = true},
    },
    ["HorseMod.HorseManeEnd"]   = { ["ManeEnd"] = {hidden = true} },
}

---Triggered before attachment data is loaded.
---This is the last possible opportunity to add new attachment data.
---@type Event
AttachmentData.preLoadAttachments = Event.new()

---Triggered after attachment data is loaded.
---@type Event
AttachmentData.postLoadAttachments = Event.new()


local function loadAttachments()
    AttachmentData.preLoadAttachments:trigger()

    local shouldError = false

    ---Used to log an error message for the HorseMod.
    ---@param message string
    local function logError(message)
        DebugLog.log("HorseMod ERROR: "..message)
        shouldError = true
    end

    local scriptManager = getScriptManager()

    --- generate slot informations
    local SLOT_DEFINITION = AttachmentData.slotsDefinitions
    local slots = AttachmentData.slots
    local maneSlots = AttachmentData.maneSlots
    local group = AttachedLocations.getGroup("Animal")
    for slot, slotData in pairs(SLOT_DEFINITION) do    
        -- verify the model attachment point
        local modelAttachment = slotData.modelAttachment
        assert(modelAttachment ~= nil, "No modelAttachment for a slot definition to link to the model attachment point.")

        -- create the apparel location
        local location = group:getOrCreateLocation(slot)
        location:setAttachmentName(modelAttachment)

        -- list slot in slots array
        table.insert(slots, slot)

        if slotData.isMane then
            local defaultMane = slotData.defaultMane
            assert(defaultMane ~= nil, "Slot ("..slot..") defined as mane without a default mane item.")
            maneSlots[slot] = defaultMane
        end
    end


    ---Automatically generate the maneByBreed table from the mane definitions.
    for breedName, hexTable in pairs(AttachmentData.MANE_HEX_BY_BREED) do
        AttachmentData.maneByBreed[breedName] = {
            hex = hexTable,
            maneConfig = AttachmentData.MANE_DEFAULT.maneConfig,
        }
    end


    ---Verify specific conditions for every attachments.
    for fullType, itemDef in pairs(AttachmentData.items) do
        local count = 0 -- count number of slots
        for slot, attachmentDef in pairs(itemDef) do repeat
            count = count + 1
            local accessoryScript = scriptManager:getItem(fullType)
            if not accessoryScript then
                logError("Horse accessory ("..fullType..") doesn't exist.")
                break
            end

            -- verify container behavior is compatible with this specific item
            local containerBehavior = attachmentDef.containerBehavior
            if containerBehavior then
                -- not a container
                if not accessoryScript:isItemType(ItemType.CONTAINER) then
                    logError("Horse accessory ("..fullType..") cannot have a container behavior because it isn't of type 'Container'.")
                    attachmentDef.containerBehavior = nil -- remove the container behavior as it cannot work
                    break
                end

                -- log worldItem full type
                local worldItem = containerBehavior.worldItem
                AttachmentData.containerItems[worldItem] = true

                -- verify the capacity of the world item and accessory are the same
                local worldItemScript = scriptManager:getItem(worldItem)
                if not worldItemScript then
                    logError("Horse accessory ("..fullType..") has a container behavior with an invalid worldItem ("..worldItem..").")
                    attachmentDef.containerBehavior = nil -- remove the container behavior as it cannot work
                    break
                end

                local accessoryCapacity = HorseUtils.getJavaField(accessoryScript, "Capacity")
                local worldItemCapacity = HorseUtils.getJavaField(worldItemScript, "Capacity")
                if accessoryCapacity ~= worldItemCapacity then
                    logError("Horse accessory ("..fullType..") doesn't have the same capacity as its 'worldItem' ("..worldItem..").")
                    -- not removing the behavior bcs it technically still can work I believe, and would possibly break player attachment containers
                    break
                end
            end
        until true end
        
        if count == 0 then
            AttachmentData.items[fullType] = nil
            logError("Horse accessory ("..fullType..") doesn't have any attachment definition for attachment slots but is defined as an attachment. Removing the item from the table for safety.")
        end
    end

    AttachmentData.postLoadAttachments:trigger()

    -- throw an error if needed.
    if shouldError then
        error("Unexpected horse accessory data registered, see the console prints above.")
    end
end

Events.OnInitGlobalModData.Add(loadAttachments)

return AttachmentData