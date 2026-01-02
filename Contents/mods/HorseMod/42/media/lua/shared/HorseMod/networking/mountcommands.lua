---@namespace HorseMod

local commands = require("HorseMod/networking/commands")

local mountcommands = {}

---@class MountArguments
---@field character integer
---@field animal integer

---@class DismountArguments
---@field character integer

---@class SendMountsArguments
---Player ids to animal ids
---@field mounts table<integer, integer>

mountcommands.Mount = commands.registerServerCommand--[[@<MountArguments>]]("Mount")
mountcommands.Dismount = commands.registerServerCommand--[[@<DismountArguments>]]("Dismount")
mountcommands.SendMounts = commands.registerServerCommand--[[@<SendMountsArguments>]]("SendMounts")

return mountcommands