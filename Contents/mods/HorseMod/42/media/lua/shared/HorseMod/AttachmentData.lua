---@namespace HorseMod

---@alias AttachmentSlot "Saddle"|"Saddlebags"|"Reins"|"ManeStart"|"ManeMid1"|"ManeMid2"|"ManeMid3"|"ManeMid4"|"ManeMid5"|"ManeEnd"|"Head"|"MountLeft"|"MountRight"

---Hex color code (#rrggbb)
---@alias HexColor string

---@class ManeColor
---@field r number
---@field g number
---@field b number

---Defines an attachment item with its associated slots and extra data if needed.
---@class AttachmentDefinition
---@field slot AttachmentSlot
---@field equipTime number?
---@field unequipTime number?
---@field equipAnim string?
---@field unequipAnim string?
---@field model string?
---@field hidden boolean?

---Maps items' fulltype to their associated attachment definition.
---@alias AttachmentsItemsMap table<string, AttachmentDefinition>

---Available item slots.
---@alias AttachmentSlots AttachmentSlot[]

---Stores the various attachment data which are required to work with attachments for horses.
---@class AttachmentData
---@field items AttachmentsItemsMap
---@field SLOTS AttachmentSlots
---@field MANE_SLOTS_SET table<AttachmentSlot, string>
---@field MANE_HEX_BY_BREED table<string, HexColor>
local AttachmentData = {
    --- Data holding attachment informations
    items = {
        -- saddles
            -- vanilla animals
        ["HorseMod.HorseSaddle_Crude"] = { slot = "Saddle" },
        ["HorseMod.HorseSaddle_Black"] = { slot = "Saddle" },
        ["HorseMod.HorseSaddle_CowHolstein"] = { slot = "Saddle" },
        ["HorseMod.HorseSaddle_CowSimmental"] = { slot = "Saddle" },
        ["HorseMod.HorseSaddle_White"] = { slot = "Saddle" },
        ["HorseMod.HorseSaddle_Landrace"] = { slot = "Saddle" },
            -- horses
        ["HorseMod.HorseSaddle_AP"] = { slot = "Saddle" },
        ["HorseMod.HorseSaddle_APHO"] = { slot = "Saddle" },
        ["HorseMod.HorseSaddle_AQHBR"] = { slot = "Saddle" },
        ["HorseMod.HorseSaddle_AQHP"] = { slot = "Saddle" },
        ["HorseMod.HorseSaddle_FBG"] = { slot = "Saddle" },
        ["HorseMod.HorseSaddle_GDA"] = { slot = "Saddle" },
        ["HorseMod.HorseSaddle_LPA"] = { slot = "Saddle" },
        ["HorseMod.HorseSaddle_T"] = { slot = "Saddle" },

        -- saddlebags
            -- vanilla animals
        ["HorseMod.HorseSaddlebags_Crude"] = { slot = "Saddlebags", container = "HorseMod.HorseSaddlebagsContainer" },
        ["HorseMod.HorseSaddlebags_Black"] = { slot = "Saddlebags", container = "HorseMod.HorseSaddlebagsContainer" },
        ["HorseMod.HorseSaddlebags_CowHolstein"] = { slot = "Saddlebags", container = "HorseMod.HorseSaddlebagsContainer" },
        ["HorseMod.HorseSaddlebags_CowSimmental"] = { slot = "Saddlebags", container = "HorseMod.HorseSaddlebagsContainer" },
        ["HorseMod.HorseSaddlebags_White"] = { slot = "Saddlebags", container = "HorseMod.HorseSaddlebagsContainer" },
        ["HorseMod.HorseSaddlebags_Landrace"] = { slot = "Saddlebags", container = "HorseMod.HorseSaddlebagsContainer" },
            -- horses
        ["HorseMod.HorseSaddlebags_AP"] = { slot = "Saddlebags", container = "HorseMod.HorseSaddlebagsContainer" },
        ["HorseMod.HorseSaddlebags_APHO"] = { slot = "Saddlebags", container = "HorseMod.HorseSaddlebagsContainer" },
        ["HorseMod.HorseSaddlebags_AQHBR"] = { slot = "Saddlebags", container = "HorseMod.HorseSaddlebagsContainer" },
        ["HorseMod.HorseSaddlebags_AQHP"] = { slot = "Saddlebags", container = "HorseMod.HorseSaddlebagsContainer" },
        ["HorseMod.HorseSaddlebags_FBG"] = { slot = "Saddlebags", container = "HorseMod.HorseSaddlebagsContainer" },
        ["HorseMod.HorseSaddlebags_GDA"] = { slot = "Saddlebags", container = "HorseMod.HorseSaddlebagsContainer" },
        ["HorseMod.HorseSaddlebags_LPA"] = { slot = "Saddlebags", container = "HorseMod.HorseSaddlebagsContainer" },
        ["HorseMod.HorseSaddlebags_T"] = { slot = "Saddlebags", container = "HorseMod.HorseSaddlebagsContainer" },

        -- reins
        ["HorseMod.HorseReins_Crude"] = { slot = "Reins", model = "HorseMod.HorseReins_Crude" },
        ["HorseMod.HorseReins_Black"] = { slot = "Reins", model = "HorseMod.HorseReins_Black" },
        ["HorseMod.HorseReins_White"] = { slot = "Reins", model = "HorseMod.HorseReins_White" },
        ["HorseMod.HorseReins_Brown"] = { slot = "Reins", model = "HorseMod.HorseReins_Brown" },

        -- manes
        ["HorseMod.HorseManeStart"] = { hidden = true, slot = "ManeStart" },
        ["HorseMod.HorseManeMid"]   = { hidden = true, slot = "ManeMid1" },
        ["HorseMod.HorseManeEnd"]   = { hidden = true, slot = "ManeEnd" },
    },

    --- Every available attachment slots
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

    --- Mane slots associated to their default mane items
    MANE_SLOTS_SET = {
        ManeStart = "HorseMod.HorseManeStart",
        ManeMid1  = "HorseMod.HorseManeMid",
        ManeMid2  = "HorseMod.HorseManeMid",
        ManeMid3  = "HorseMod.HorseManeMid",
        ManeMid4  = "HorseMod.HorseManeMid",
        ManeMid5  = "HorseMod.HorseManeMid",
        ManeEnd   = "HorseMod.HorseManeEnd",
    },

    --- Breeds associated to their mane colors
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

    --- Sufixes for reins model swapping during horse riding
    REIN_STATES = {
        idle = "",
        walking = "_Walking",
        trot = "_Troting",
        gallop = "_Running"
    },
}

return AttachmentData