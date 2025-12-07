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
---@field anim table<string,string>? animation to play during equip
---@field shouldHold boolean? whenever the item should be held in hand when equipping it

---@class ContainerBehavior
---@field worldItem string

---Defines an attachment item with its associated slots and extra data if needed.
---@class AttachmentDefinition
---@field equipBehavior EquipBehavior? Equip timed action behavior
---@field unequipBehavior EquipBehavior? Unequip timed action behavior
---@field model string? Model script ID to show when attached [not fully tested]
---@field hidden boolean? Hide the item in menus [not fully tested]
---@field containerBehavior ContainerBehavior? Container behavior.

---@alias ItemDefinition table<AttachmentSlot, AttachmentDefinition>

---Stores the various attachment data which are required to work with attachments for horses.
local AttachmentData = {
    ---Maps items' fulltype to their associated attachment definition.
    ---@type table<string, ItemDefinition>
    items = {},

    ---Holds the unique full types of world items for container behaviors.
    ---@type table<string, true>
    CONTAINER_ITEMS = {},

    ---Default attachment definitions.
    ---@type {[string]: ItemDefinition}
    DEFAULT_ATTACHMENT_DEFS = {
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
    ---@type table<AttachmentSlot, {modelAttachment: string, isMane: boolean?, defaultMane: string?}>
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
    ---Automatically generated in `server/HorseMod/AttachmentsLoad.lua` from `SLOTS_DEFINITION`.
    ---@type AttachmentSlot[]
    SLOTS = {},

    ---Mane slots associated to their default mane items.
    ---Automatically generated in `server/HorseMod/AttachmentsLoad.lua` from `SLOTS_DEFINITION`.
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
    ["HorseMod.HorseManeMid"]   = { ["ManeMid1"] = {hidden = true} },
    ["HorseMod.HorseManeEnd"]   = { ["ManeEnd"] = {hidden = true} },
}

---@param itemDefinitions table<string, ItemDefinition>
AttachmentData.addNewAttachments = function(itemDefinitions)
    local items = AttachmentData.items
    for fullType, itemDef in pairs(itemDefinitions) do
        local itemDefEntry = items[fullType] or {}
        for slot, attachmentDef in pairs(itemDef) do
            local attachmentDefEntry = itemDefEntry[slot]
            if not attachmentDefEntry then
                itemDefEntry[slot] = itemDef
            end
        end
        items[fullType] = itemDefEntry
    end
end

return AttachmentData