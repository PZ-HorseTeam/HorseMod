require("ISUI/Animal/ISAnimalContextMenu")

local HorseAttachmentLocations = require("HorseMod/horse/attachments/AttachmentLocations")
require("HorseMod/horse/attachments/AttachmentUtils")
require("HorseMod/horse/attachments/AttachmentSaddlebags")
require("HorseMod/horse/attachments/AttachmentGear")
require("HorseMod/horse/attachments/AttachmentManes")
local HorseAttachmentContextMenu = require("HorseMod/horse/attachments/AttachmentContextMenu")
require("HorseMod/horse/attachments/AttachmentReapply")
require("HorseMod/HorseManager")

---@class HorseAttachmentsModule
local HorseAttachments = {}

---@type HorseAttachmentItemsMap
HorseAttachments.items = HorseAttachmentLocations.defaultItems()

HorseAttachmentContextMenu.init(HorseAttachments.items)

return HorseAttachments
