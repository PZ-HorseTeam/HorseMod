---@namespace HorseMod

local commands = require("HorseMod/networking/commands")


---@class HorseSoundStateArguments
---@field rider integer|string
---@field animal integer
---@field gait MovementState
---@field jumping boolean


---@class HorseSoundOneShotArguments
---@field animal integer
---@field sound string


local soundcommands = {}

---Send on every rider movement state change. Drives remote rider horse footstep sound
---on every other client
soundcommands.HorseSoundState = commands.registerServerCommand--[[@<HorseSoundStateArguments>]]("HorseSoundState")

---Send for one-shot horse sounds that remote players must hear reliably
soundcommands.HorseSoundOneShot = commands.registerServerCommand--[[@<HorseSoundOneShotArguments>]]("HorseSoundOneShot")


return soundcommands
