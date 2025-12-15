---@namespace HorseMod

---Available attachment slots.
---@alias AttachmentSlot "Saddle"|"Saddlebags"|"Reins"|"ManeStart"|"ManeMid1"|"ManeMid2"|"ManeMid3"|"ManeMid4"|"ManeMid5"|"ManeEnd"|"Head"|"MountLeft"|"MountRight"


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


---Table holding a RGB mane color.
---@class ManeColor
---@field r number
---@field g number
---@field b number


---Equip behavior to use during equip or unequip timed actions for attachments.
---@class EquipBehavior
---
---Time to equip, if `-1` the animation defines the end time.
---@field time number
---
---Animation to play during equip, it must be an AnimNode variable condition.
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
    ---Automatically generated in `server/HorseMod/AttachmentsLoad.lua` from :lua:obj:`HorseMod.ContainerBehavior.worldItem`.
    ---@type table<string, true>
    CONTAINER_ITEMS = {},

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
    },

    ---Sets attachment model points and mane properties for attachment slots.
    ---@type table<AttachmentSlot, SlotDefinition>
    SLOTS_DEFINITION = {
        ---ACCESSORIES
        ["Saddle"] = {modelAttachment="saddle"},
        ["Saddlebags"] = {modelAttachment="saddlebags"},
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
    ---Automatically generated in `server/HorseMod/AttachmentsLoad.lua` from :lua:obj:`HorseMod.attachments.AttachmentData.SLOTS_DEFINITION`.
    ---@type AttachmentSlot[]
    SLOTS = {},

    ---Mane slots associated to their default mane items.
    ---Automatically generated in `server/HorseMod/AttachmentsLoad.lua` from :lua:obj:`HorseMod.attachments.AttachmentData.SLOTS_DEFINITION`.
    ---@type table<AttachmentSlot, string>
    MANE_SLOTS_SET = {},

    ---Breeds associated to their mane colors.
    ---@type table<string, HexColor>
    MANE_HEX_BY_BREED = {
        american_quarter = "#EADAB6",
        american_paint = "#FBDEA7",
        appaloosa = "#24201D",
        thoroughbred = "#140C08",
        blue_roan = "#19191C",
        spotted_appaloosa = "#FFF7E4",
        american_paint_overo = "#292524",
        flea_bitten_grey = "#FCECC5",
        _default = "#6B5642",
    },

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
    ["HorseMod.HorseSaddle_AP"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
    ["HorseMod.HorseSaddle_APHO"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
    ["HorseMod.HorseSaddle_AQHBR"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
    ["HorseMod.HorseSaddle_AQHP"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
    ["HorseMod.HorseSaddle_FBG"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
    ["HorseMod.HorseSaddle_GDA"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
    ["HorseMod.HorseSaddle_LPA"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,
    ["HorseMod.HorseSaddle_T"] = DEFAULT_ATTACHMENT_DEFS.SADDLE,

    -- saddlebags
        -- vanilla animals
    ["HorseMod.HorseSaddlebags_Crude"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_Black"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_CowHolstein"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_CowSimmental"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_White"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_Landrace"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
        -- horses
    ["HorseMod.HorseSaddlebags_AP"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_APHO"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_AQHBR"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_AQHP"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_FBG"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_GDA"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_LPA"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,
    ["HorseMod.HorseSaddlebags_T"] = DEFAULT_ATTACHMENT_DEFS.SADDLEBAGS,

    -- reins
    ["HorseMod.HorseReins_Crude"] = { ["Reins"] = {model = "HorseMod.HorseReins_Crude"} },
    ["HorseMod.HorseReins_Black"] = { ["Reins"] = {model = "HorseMod.HorseReins_Black"} },
    ["HorseMod.HorseReins_White"] = { ["Reins"] = {model = "HorseMod.HorseReins_White"} },
    ["HorseMod.HorseReins_Brown"] = { ["Reins"] = {model = "HorseMod.HorseReins_Brown"} },

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

---Used to define new attachments.
---@param itemDefinitions table<string,ItemDefinition>
AttachmentData.addNewAttachments = function(itemDefinitions)
    for fullType, itemDef in pairs(itemDefinitions) do
        for slot, attachmentDef in pairs(itemDef) do
            AttachmentData.addNewAttachment(fullType, slot, attachmentDef)
        end
    end
end

---@param fullType string
---@param slot AttachmentSlot
---@param attachmentDef AttachmentDefinition
AttachmentData.addNewAttachment = function(fullType, slot, attachmentDef)
    -- retrieve item definition
    local items = AttachmentData.items
    local itemDefEntry = items[fullType] or {}

    -- set or overwrite
    local attachmentDefEntry = itemDefEntry[slot]
    assert(not attachmentDefEntry, "AttachmentData.addNewAttachment: Attachment for item '" .. fullType .. "' on slot '" .. slot .. "' already exists!")

    itemDefEntry[slot] = attachmentDef
    items[fullType] = itemDefEntry
end

AttachmentData.addNewSlot = function(slot, slotDefinition)
    local slotsDef = AttachmentData.SLOTS_DEFINITION
    assert(not slotsDef[slot], "AttachmentData.addNewSlot: Slot '" .. slot .. "' already exists!")

    slotsDef[slot] = slotDefinition
end

return AttachmentData