---@namespace HorseMod

-- i would prefer to do this the other way around so that the main body isn't one layer deep,
-- but emmylua only looks at the first return value, so there would be no intellisense if i did that
if not (isClient() or isServer()) then
    ---@class IdMap<T>
    ---@field objectById table<integer, T>
    ---@field idByObject table<T, integer>
    ---@field max integer
    local IdMap = {}
    IdMap.__index = {}

    ---@param object T
    ---@return integer
    function IdMap:getOrAddId(object)
        local id = self.idByObject[object]

        if not id then
            id = self.max
            self.objectById[object] = id
            self.max = self.max + 1
        end

        return id
    end

    ---@param id integer
    ---@return T?
    ---@nodiscard
    function IdMap:getObject(id)
        return self.objectById[id]
    end

    ---@param object T
    function IdMap:removeObject(object)
        local id = self.idByObject[object]
        self.idByObject[object] = nil
        self.objectById[id] = nil
    end

    ---@generic T
    ---@return IdMap<T>
    ---@nodiscard
    function IdMap.new()
        return setmetatable(
            {
                objectById = {},
                idByObject = {},
                max = 0
            },
            IdMap
        )
    end


    ---Singleplayer-only module containing lookups for objects needed in networking functions.
    ---
    ---Used to workaround certain networking functions not working in singleplayer without needing separate code.
    ---
    ---Trying to access any of this module's members in multiplayer will raise an error.
    local spobjects = {}

    ---@type IdMap<IsoAnimal>
    spobjects.animal = IdMap.new()

    local function releaseRemovedAnimals()
        for _, animal in pairs(spobjects.animal.objectById) do
            if not animal:isExistInTheWorld() then
                spobjects.animal:removeObject(animal)
            end
        end
    end

    Events.OnTick.Add(function(tick)
        -- we don't need to do this frequently at all
        if tick % 600 == 0 then
            releaseRemovedAnimals()
        end
    end)

    return spobjects
end

---@type metatable
local __errorMetatable = {}
function __errorMetatable:__index(key)
    error(
        string.format(
            "attempted index %s of spobjects in multiplayer",
            tostring(key)
        )
    )
end

return setmetatable({}, __errorMetatable)