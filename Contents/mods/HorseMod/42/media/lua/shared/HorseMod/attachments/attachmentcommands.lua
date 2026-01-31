---@namespace HorseMod

local commands = require("HorseMod/networking/commands")

local attachmentcommands = {}

attachmentcommands.AttachmentChanged = commands.registerServerCommand--[[@<{animal: integer, slot: AttachmentSlot, item: string?}>]]("AttachmentChanged")

return attachmentcommands