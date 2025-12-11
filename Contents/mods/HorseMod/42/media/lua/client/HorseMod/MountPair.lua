---@namespace HorseMod


---Defines a mounting pair with the rider and the mount and allows easy double control.
---@class MountPair
---
---@field rider IsoPlayer
---
---@field mount IsoAnimal
local MountPair = {}
MountPair.__index = MountPair

---Get the animation variable for both pairs. Returns false if all are false, else true.
---@param key string
function MountPair:getAnimationVariableBoolean(key)
    local boolRider = self.rider:getVariableBoolean(key)
    local boolMount = self.mount:getVariableBoolean(key)
    return boolRider or boolMount -- false if all false, else true
end


---Set the animation variable for both pairs.
---@param key string
---@param value number | boolean | string
function MountPair:setAnimationVariable(key, value)
    self.rider:setVariable(key, value)
    self.mount:setVariable(key, value)
end


---Set the direction for both pairs.
---@param direction IsoDirections
function MountPair:setDirection(direction)
    self.mount:setDir(direction)
    self.rider:setDir(direction)
end


---Create a new mount pair.
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