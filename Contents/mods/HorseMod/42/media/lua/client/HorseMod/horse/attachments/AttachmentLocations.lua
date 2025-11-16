---@class HorseAttachmentItemDefinition
---@field slot string


---@class HorseAttachmentGroundData
---@field x number|nil
---@field y number|nil
---@field z number|nil
---@field id integer|nil


---@class HorseSaddlebagData
---@field active boolean|nil
---@field missingCount integer|nil
---@field lastSpawnTick integer|nil
---@field itemId integer|nil
---@field x number|nil
---@field y number|nil
---@field z number|nil
---@field equipped boolean|nil


---@alias HorseAttachmentItemsMap table<string, HorseAttachmentItemDefinition|string>


---@class HorseAttachmentLocations
local HorseAttachmentLocations = {}

local group = AttachedLocations.getGroup("Animal")

local saddle = group:getOrCreateLocation("Saddle")
saddle:setAttachmentName("saddle")

local saddlebags = group:getOrCreateLocation("Saddlebags")
saddlebags:setAttachmentName("saddlebags")

local head = group:getOrCreateLocation("Head")
head:setAttachmentName("head")

local reins = group:getOrCreateLocation("Reins")
reins:setAttachmentName("reins")

local mountLeft = group:getOrCreateLocation("MountLeft")
mountLeft:setAttachmentName("mountLeft")

local mountRight = group:getOrCreateLocation("MountRight")
mountRight:setAttachmentName("mountRight")

local maneStart = group:getOrCreateLocation("ManeStart")
local maneMid1 = group:getOrCreateLocation("ManeMid1")
local maneMid2 = group:getOrCreateLocation("ManeMid2")
local maneMid3 = group:getOrCreateLocation("ManeMid3")
local maneMid4 = group:getOrCreateLocation("ManeMid4")
local maneMid5 = group:getOrCreateLocation("ManeMid5")
local maneEnd = group:getOrCreateLocation("ManeEnd")
maneStart:setAttachmentName("maneStart")
maneMid1:setAttachmentName("maneMid1")
maneMid2:setAttachmentName("maneMid2")
maneMid3:setAttachmentName("maneMid3")
maneMid4:setAttachmentName("maneMid4")
maneMid5:setAttachmentName("maneMid5")
maneEnd:setAttachmentName("maneEnd")

HorseAttachmentLocations.SADDLEBAG_SLOT = "Saddlebags"
HorseAttachmentLocations.SADDLEBAG_FULLTYPE = "HorseMod.HorseSaddleBags"
HorseAttachmentLocations.SADDLEBAG_CONTAINER_TYPE = "HorseMod.HorseSaddleBagsContainer"

HorseAttachmentLocations.MANE_ITEM_BY_SLOT = {
    ManeStart = "HorseMod.HorseManeStart",
    ManeMid1  = "HorseMod.HorseManeMid",
    ManeMid2  = "HorseMod.HorseManeMid",
    ManeMid3  = "HorseMod.HorseManeMid",
    ManeMid4  = "HorseMod.HorseManeMid",
    ManeMid5  = "HorseMod.HorseManeMid",
    ManeEnd   = "HorseMod.HorseManeEnd",
}

HorseAttachmentLocations.MANE_HEX_BY_BREED = {
    american_quarter = "#EADAB6",
    american_paint = "#FBDEA7",
    appaloosa = "#24201D",
    thoroughbred = "#140C08",
    blue_roan = "#19191C",
    spotted_appaloosa = "#FFF7E4",
    american_paint_overo = "#292524",
    flea_bitten_grey = "#FCECC5",
    __default = "#6B5642",
}

HorseAttachmentLocations.MANE_SLOTS_SET = {
    ManeStart = true,
    ManeMid1 = true,
    ManeMid2 = true,
    ManeMid3 = true,
    ManeMid4 = true,
    ManeMid5 = true,
    ManeEnd = true,
}

HorseAttachmentLocations.SLOTS = {
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
}


---@return HorseAttachmentItemsMap
function HorseAttachmentLocations.defaultItems()
    return {
        ["HorseMod.HorseSaddle"] = { slot = "Saddle" },
        ["HorseMod.HorseBackpack"] = { slot = "Saddle" },
        ["HorseMod.HorseSaddleBags"] = { slot = "Saddlebags" },
        ["HorseMod.HorseReins"] = { slot = "Reins" },
        ["HorseMod.HorseManeStart"] = { slot = "ManeStart" },
        ["HorseMod.HorseManeMid"]   = { slot = "ManeMid1" },
        ["HorseMod.HorseManeEnd"]   = { slot = "ManeEnd" },
    }
end

return HorseAttachmentLocations
