---@namespace HorseMod

---@TODO use the HorseDefinition table to check for horses directly ?
local HORSE_TYPES = {
    ["stallion"] = true,
    ["mare"] = true,
    ["filly"] = true
}

local HorseUtils = {}

---Utility function to retrieve fields of specific Java object instances.
---@param object any
---@param field string
HorseUtils.getJavaField = function(object, field)
    local offset = string.len(field)
    for i = 0, getNumClassFields(object) - 1 do
        local m = getClassField(object, i)
        if string.sub(tostring(m), -offset) == field then
            return getClassFieldVal(object, m)
        end
    end
    return nil -- no field found
end

---@param seconds number
---@param callback fun(...)
---@param ... any
HorseUtils.runAfter = function(seconds, callback, ...)
    local elapsed = 0 --[[@as number]]
    local gameTime = GameTime.getInstance()
    local args = {...}

    local function tick()
        elapsed = elapsed + gameTime:getTimeDelta()
        if elapsed < seconds then
            return
        end

        Events.OnTick.Remove(tick)
        callback(unpack(args))
    end

    Events.OnTick.Add(tick)

    return function()
        Events.OnTick.Remove(tick)
    end
end


---Checks whether an animal is a horse.
---@param animal IsoAnimal The animal to check.
---@return boolean isHorse Whether the animal is a horse.
---@nodiscard
HorseUtils.isHorse = function(animal)
    return HORSE_TYPES[animal:getAnimalType()] or false
end

---@param animal IsoAnimal
---@return boolean
---@nodiscard
HorseUtils.isAdult = function(animal)
    local type = animal:getAnimalType()
    return type == "stallion" or type == "mare"
end

---@param horse IsoAnimal
---@return string
HorseUtils.getBreedName = function(horse)
    local breed = horse:getBreed()
    return breed and breed:getName() or "_default"
end





---Formats translation entries that use such a format:
---```lua
---local params = {param1 = "Str1", paramNamed = "Str2", helloWorld="Str3",}
---local txt = formatTemplate("{param1} {paramNamed} {helloWorld}", params)
---```
---@param template string
---@param params table<string, string>
---@nodiscard
HorseUtils.formatTemplate = function(template, params)
    return template:gsub("{(%w+)}", params)
end

---Trims whitespace from both ends of a string.
---@param value string
---@return string?
---@nodiscard
local function trim(value)
    return value:match("^%s*(.-)%s*$")
end



---@param hex string|nil
---@return number, number, number
---@nodiscard
HorseUtils.hexToRGBf = function(hex)
    if not hex then
        return 1, 1, 1
    end
    hex = tostring(hex):gsub("#", "")
    if #hex == 3 then
        hex = hex:sub(1, 1)
            .. hex:sub(1, 1)
            .. hex:sub(2, 2)
            .. hex:sub(2, 2)
            .. hex:sub(3, 3)
            .. hex:sub(3, 3)
    end
    if #hex ~= 6 then
        return 1, 1, 1
    end
    local r = (tonumber(hex:sub(1, 2), 16) or 255) / 255
    local g = (tonumber(hex:sub(3, 4), 16) or 255) / 255
    local b = (tonumber(hex:sub(5, 6), 16) or 255) / 255
    return r, g, b
end

---@param debugString string The string from getAnimationDebug().
---@param matchString string The name of the animation to look for.
---@return table? animationData The animation names found between "Anim:" and "Weight".
---@nodiscard
HorseUtils.getAnimationFromDebugString = function(debugString, matchString)
    local searchStart = 1
    local animationData = {name = "", weight = 0}

    while true do
        local _, animLabelEnd = string.find(debugString, "Anim:", searchStart, true)
        if not animLabelEnd then
            break
        end

        local weightStart = string.find(debugString, "Weight", animLabelEnd + 1, true)
        if not weightStart then
            break
        end

        local rawName = string.sub(debugString, animLabelEnd + 1, weightStart - 1)
        local name = trim(rawName)
        if name == matchString then
            local weightValue
            local weightColon = string.find(debugString, ":", weightStart, true)
            if weightColon then
                local nextNewline = string.find(debugString, "\n", weightColon + 1, true)
                local weightEnd = (nextNewline or (#debugString + 1)) - 1
                local rawWeight = string.sub(debugString, weightColon + 1, weightEnd)
                weightValue = tonumber(trim(rawWeight))
            end
            print("Weight value of anim: ", weightValue)
            animationData.name = name
            animationData.weight = weightValue
            return animationData
        end

        searchStart = weightStart + 1
    end
    return nil
end

---Gets the lowest square with a floor under the given coordinates.
---@param x number
---@param y number
---@param z number
---@return IsoGridSquare?
HorseUtils.getBottom = function(x,y,z)
    local square = getSquare(x,y,z)
    local lastValidSquare = square ~= nil and square or nil
    while square and not square:getFloor() do
        z = z - 1
        square = getSquare(x,y,z)
        lastValidSquare = square ~= nil and square or nil
        if z < 32 then break end -- prevent infinite loop
    end

    return lastValidSquare
end

return HorseUtils
