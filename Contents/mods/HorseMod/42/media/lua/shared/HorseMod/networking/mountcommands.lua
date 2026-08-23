---@namespace HorseMod

local commands = require("HorseMod/networking/commands")

local mountcommands = {}

---@class MountArguments
---@field character integer|string
---@field animal integer

---@class DismountArguments
---@field character integer|string
---@field animal integer

---@class MountRequestArguments
---@field animal integer

---@class DismountRequestArguments
---@field animal integer
---@field attachment string

---@class UrgentDismountArguments
---@field character integer|string
---The animation variable to raise on the rider so the fall/death animation
---plays locally (setVariable is local-only, so remote clients need telling).
---@field dismountType string

---@class HorseFleeArguments
---@field animal integer
---@field character integer|string

---@class SendMountsArguments
---Player ids to animal ids
---@field mounts table<integer|string, integer>

---@class RidingInputArguments
---@field animal integer
---@field seq integer
---@field moveX number
---@field moveY number
---@field run boolean
---@field trot boolean
---@field jump boolean
---@field x number
---@field y number
---@field z number
---@field dir integer
---@field speed number
---@field hasReins boolean

---@class RequestMountsArguments
---Chunk grid width of the requesting client, used to approximate its relevance area.
---@field w integer

---Descriptive riding snapshot used inside the mod. It is converted to and from
---the compact wire form by :lua:module:`HorseMod.networking.ridingcodec`.
---@class RidingStateArguments
---@field character integer
---@field animal integer
---@field seq integer
---@field x number
---@field y number
---@field z number
---@field dir integer
---@field speed number
---@field gallop boolean
---@field trot boolean
---@field jump boolean
---@field turn integer
---@field hasReins boolean
---@field idleToRun boolean

---@class KickRequestArguments
---@field zombieId integer
---@field kickLeft boolean

---@class KickPerformedArguments
---@field character integer|string
---@field kickLeft boolean
---@field zombieId integer

mountcommands.Mount = commands.registerServerCommand--[[@<MountArguments>]]("Mount")
mountcommands.Dismount = commands.registerServerCommand--[[@<DismountArguments>]]("Dismount")
mountcommands.SendMounts = commands.registerServerCommand--[[@<SendMountsArguments>]]("SendMounts")
mountcommands.RidingState = commands.registerServerCommand--[[@<RidingStateWire>]]("RidingState")
mountcommands.UrgentDismount = commands.registerServerCommand--[[@<UrgentDismountArguments>]]("UrgentDismount")
mountcommands.KickPerformed = commands.registerServerCommand--[[@<KickPerformedArguments>]]("KickPerformed")

mountcommands.RidingInput = commands.registerClientCommand--[[@<RidingInputArguments>]]("RidingInput")
mountcommands.RequestMounts = commands.registerClientCommand--[[@<RequestMountsArguments>]]("RequestMounts")
mountcommands.MountRequest = commands.registerClientCommand--[[@<MountRequestArguments>]]("MountRequest")
mountcommands.DismountRequest = commands.registerClientCommand--[[@<DismountRequestArguments>]]("DismountRequest")
mountcommands.KickRequest = commands.registerClientCommand--[[@<KickRequestArguments>]]("KickRequest")
mountcommands.HorseFleeRequest = commands.registerClientCommand--[[@<HorseFleeArguments>]]("HorseFleeRequest")

return mountcommands
