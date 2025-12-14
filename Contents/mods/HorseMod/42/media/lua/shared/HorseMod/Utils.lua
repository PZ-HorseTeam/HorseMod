---@namespace HorseMod

---REQUIREMENTS
local AttachmentData = require("HorseMod/attachments/AttachmentData")

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

---@class HorseModData
---@field bySlot table<AttachmentSlot, string> Attachments of the horse.
---@field maneColors table<AttachmentSlot, ManeColor|nil> Manes of the horse and their associated color.
---@field containers table<AttachmentSlot, ContainerInformation>

---@param animal IsoAnimal
---@return HorseModData
HorseUtils.getModData = function(animal)
    local md = animal:getModData()
    local horseModData = md.horseModData
    if not horseModData then
        md.horseModData = {
            bySlot = HorseUtils.tableCopy(AttachmentData.MANE_SLOTS_SET),
            maneColors = {},
            containers = {},
        } --[[@as HorseModData]]
        horseModData = md.horseModData
    end
    return horseModData
end

---@param horse IsoAnimal
---@return integer
HorseUtils.getHorseID = function(horse)
    return horse:getAnimalID()
end

---@param horse IsoAnimal
---@param name string
---@return number x
---@return number y
---@return number z
---@nodiscard
HorseUtils.getMountWorld = function(horse, name)
    local v = horse:getAttachmentWorldPos(name)
    if v then return v:x(), v:y(), v:z() end

    local dx = (name == "mountLeft") and -0.6 or 0.6
    return horse:getX() + dx, horse:getY(), horse:getZ()
end


---@param character IsoGameCharacter
---@param horse IsoAnimal
---@return number x
---@return number y
---@return number z
---@return string attachment
---@nodiscard
HorseUtils.getClosestMount = function(character, horse)
    local ln = "mountLeft"
    local lx, ly, lz = HorseUtils.getMountWorld(horse, ln)
    local rn = "mountRight"
    local rx, ry, rz = HorseUtils.getMountWorld(horse, rn)
    local px, py     = character:getX(), character:getY()

    local dl = (px - lx) * (px - lx) + (py - ly) * (py - ly)
    local dr = (px - rx) * (px - rx) + (py - ry) * (py - ry)

    local tx, ty, tz, tn = lx, ly, lz, ln
    if dr < dl then
        tx, ty, tz, tn = rx, ry, rz, rn
    end

    return tx, ty, tz, tn
end


---Unlock functions cached for horses.
---@type table<IsoAnimal, fun()?>
local _unlocks = {}

---@param horse IsoAnimal
---@return fun()
---@return IsoDirections
HorseUtils.lockHorseForInteraction = function(horse)
    -- make sure to unlock the horse if it was already unlocked
    local lastUnlock = _unlocks[horse]
    if lastUnlock then
        lastUnlock()
    end

    -- stop any pathfinding of the horse and lock it in place
    horse:getPathFindBehavior2():reset()
    local bh = horse:getBehavior()
    bh:setBlockMovement(true)
    bh:setDoingBehavior(false)
    horse:stopAllMovementNow()

    -- stop the horse from moving
    local lockDir = horse:getDir()
    local function lockTick()
        ---@diagnostic disable-next-line
        if horse and horse:isExistInTheWorld() then horse:setDir(lockDir) end
    end
    Events.OnTick.Add(lockTick)

    -- unlock function to stop the horse from staying in place
    local function unlock()
        _unlocks[horse] = nil -- remove the cached unlock
        Events.OnTick.Remove(lockTick)
        if horse and horse:isExistInTheWorld() then horse:getBehavior():setBlockMovement(false) end
    end

    -- cache unlock
    _unlocks[horse] = unlock

    return unlock, lockDir
end


---@type table<string, string>
local _attachmentSide = {
    ["mountLeft"] = "Left",
    ["mountRight"] = "Right",
}
---Adds a timed action to the player to pathfind to the horse location.
---@TODO the pathfinding to go and equip/unequip the horse do not take into account whenever the square to path has a direct line of sight on the horse
---@param player IsoPlayer
---@param horse IsoAnimal
---@return fun() unlock
---@return string side
HorseUtils.pathfindToHorse = function(player, horse)
    local unlock, lockDir = HorseUtils.lockHorseForInteraction(horse)

    local mx, my, mz, mn = HorseUtils.getClosestMount(player, horse)
    local path = ISPathFindAction:pathToLocationF(player, mx, my, mz)

    -- retrieve where the player must look by first making a copy of the lockDir
    local vec2 = lockDir:ToVector()
    local tempDir = IsoDirections.fromAngle(vec2)
    local playerDir = mn == "mountLeft" and tempDir:RotRight() or tempDir:RotLeft()
    
    -- pathfinding to horse
    local function cleanupOnFail()
        unlock()
    end

    path:setOnFail(cleanupOnFail)
    function path:stop()
        cleanupOnFail()
        ISPathFindAction.stop(self)
    end
    path:setOnComplete(function(p)
        p:setDir(playerDir)
    end, player)
    ISTimedActionQueue.add(path)

    return unlock, _attachmentSide[mn]
end


---@param animal IsoAnimal
---@param slot string
---@return InventoryItem | nil
---@nodiscard
HorseUtils.getAttachedItem = function(animal, slot)
    -- TODO: check if this will actually be nil in real circumstances, doesn't seem like it!
    local attachedItems = animal:getAttachedItems()
    if attachedItems then
        return attachedItems:getItem(slot)
    end

    return nil
end


---@param animal IsoAnimal
---@return InventoryItem | nil
---@nodiscard
HorseUtils.getSaddle = function(animal)
    local saddle = HorseUtils.getAttachedItem(animal, "Saddle")
    if not saddle then
        return nil
    else
        return saddle
    end
end


---@param animal IsoAnimal
---@return InventoryItem | nil
---@nodiscard
HorseUtils.getReins = function(animal)
    local reins = HorseUtils.getAttachedItem(animal, "Reins")
    if not reins then
        return nil
    else
        return reins
    end
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

---Make a copy of a table
---@param tbl table
---@return table
HorseUtils.tableCopy = function(tbl)
    local copy = {}
    for k,v in pairs(tbl) do
        copy[k] = v
    end
    return copy
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

---Trims whitespace from both ends of a string.
---@param value string
---@return string?
---@nodiscard
local function trim(value)
    return value:match("^%s*(.-)%s*$")
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

return HorseUtils
