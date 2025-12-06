---@namespace HorseMod

---Available attachment slots.
---@alias AttachmentSlot "Saddle"|"Saddlebags"|"Reins"|"ManeStart"|"ManeMid1"|"ManeMid2"|"ManeMid3"|"ManeMid4"|"ManeMid5"|"ManeEnd"|"Head"|"MountLeft"|"MountRight"

---Hex color code (#rrggbb).
---@alias HexColor string

---Table holding a RGB mane color.
---@class ManeColor
---@field r number
---@field g number
---@field b number

---Equip behavior to use during equip or unequip actions.
---@class EquipBehavior
---@field time number time to equip, if `-1` the animation defines the end time
---@field anim string? animation to play during equip
---@field shouldHold boolean? whenever the item should be held in hand when equipping it

---@class ContainerBehavior
---@field worldItem string

---Defines an attachment item with its associated slots and extra data if needed.
---@class AttachmentDefinition
---@field slot AttachmentSlot Slot the attachment goes on
---@field equipBehavior EquipBehavior? Equip timed action behavior
---@field unequipBehavior EquipBehavior? Unequip timed action behavior
---@field model string? Model script ID to show when attached [not fully tested]
---@field hidden boolean? Hide the item in menus [not fully tested]
---@field containerBehavior ContainerBehavior? Container behavior.

---Stores the various attachment data which are required to work with attachments for horses.
local AttachmentData = {
    ---Maps items' fulltype to their associated attachment definition.
    ---@type table<string, AttachmentDefinition>
    items = {},

    ---Holds the unique full types of world items for container behaviors.
    ---@type table<string, true>
    CONTAINER_ITEMS = {},

    ---Default attachment definitions.
    ---@type table<string, AttachmentDefinition>
    DEFAULT_ATTACHMENT_DEFS = {
        SADDLE = { 
            slot = "Saddle", 
            equipBehavior = {
                time = -1,
                anim = "Horse_EquipSaddle", 
                shouldHold = true,
            },
        },
        SADDLEBAGS = { 
            slot = "Saddlebags", 
            containerBehavior = {
                worldItem = "HorseMod.HorseSaddlebagsContainer",
            },
        },
    },

    ---Every available attachment slots.
    ---@type AttachmentSlot[]
    SLOTS = {
        "Saddle",
        "Saddlebags",
        "Head",
        "Reins",
        "MountLeft",
        "MountRight",
        "ManeStart",
        "ManeMid1",
        "ManeMid2",
        "ManeMid3",
        "ManeMid4",
        "ManeMid5",
        "ManeEnd",
    },

    ---Mane slots associated to their default mane items.
    ---@type table<AttachmentSlot, string>
    MANE_SLOTS_SET = {
        ManeStart = "HorseMod.HorseManeStart",
        ManeMid1  = "HorseMod.HorseManeMid",
        ManeMid2  = "HorseMod.HorseManeMid",
        ManeMid3  = "HorseMod.HorseManeMid",
        ManeMid4  = "HorseMod.HorseManeMid",
        ManeMid5  = "HorseMod.HorseManeMid",
        ManeEnd   = "HorseMod.HorseManeEnd",
    },

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
        __default = "#6B5642",
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
    ["HorseMod.HorseReins_Crude"] = { slot = "Reins", model = "HorseMod.HorseReins_Crude" },
    ["HorseMod.HorseReins_Black"] = { slot = "Reins", model = "HorseMod.HorseReins_Black" },
    ["HorseMod.HorseReins_White"] = { slot = "Reins", model = "HorseMod.HorseReins_White" },
    ["HorseMod.HorseReins_Brown"] = { slot = "Reins", model = "HorseMod.HorseReins_Brown" },

    -- manes
    ["HorseMod.HorseManeStart"] = { hidden = true, slot = "ManeStart" },
    ["HorseMod.HorseManeMid"]   = { hidden = true, slot = "ManeMid1" },
    ["HorseMod.HorseManeEnd"]   = { hidden = true, slot = "ManeEnd" },
}

return AttachmentData