---@namespace HorseMod

---@class Event<T...>
---
---@field callbacks fun(...:T...)[]
local __Event = {}
__Event.__index = __Event


---@param callback fun(...:T...)
function __Event:add(callback)
    self.callbacks[#self.callbacks + 1] = callback
end


---@param ... T...
function __Event:trigger(...)
    for i = 1, #self.callbacks do
        self.callbacks[i](...)
    end
end


local Event = {}


---@return Event
---@nodiscard
function Event.new()
    return setmetatable(
        {
            callbacks = table.newarray()
        },
        __Event
    )
end


return Event