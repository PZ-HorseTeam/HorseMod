---@namespace HorseMod


---@class MountPair
---
---@field rider IsoPlayer
---
---@field mount IsoAnimal
local MountPair = {}
MountPair.__index = MountPair


---@param key string
---@param value number | boolean
function MountPair:setAnimationVariable(key, value)
    self.rider:setVariable(key, value)
    self.mount:setVariable(key, value)
end


---@param direction IsoDirections
function MountPair:setDirection(direction)
    self.mount:setDir(direction)
    self.rider:setDir(direction)
end


---@param rider IsoPlayer
---@param mount IsoAnimal
---@return self
---@nodiscard
function MountPair.new(rider, mount)
    return setmetatable(
        {
            rider = rider,
            mount = mount
        },
        MountPair
    )
end


return MountPair