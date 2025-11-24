local HORSE_TYPES = {
    ["stallion"] = true,
    ["mare"] = true,
    ["filly"] = true
}

local HorseUtils = {}

---Checks whether an animal is a horse.
---@param animal IsoAnimal The animal to check.
---@return boolean isHorse Whether the animal is a horse.
HorseUtils.isHorse = function(animal)
    return HORSE_TYPES[animal:getAnimalType()] or false
end

---@param animal IsoAnimal
---@return table, table
HorseUtils.getModData = function(animal)
    local md = animal:getModData()
    local horseModData = md.horseModData
    if not horseModData then
        md.horseModData = {
            bySlot = {},
            ground = {},
        }
        horseModData = md.horseModData
    end
    return horseModData
end

---@param horse IsoAnimal
---@param name string
HorseUtils.getMountWorld = function(horse, name)
    local v = horse:getAttachmentWorldPos(name)
    if v then return v:x(), v:y(), v:z() end

    local dx = (name == "mountLeft") and -0.6 or 0.6
    return horse:getX() + dx, horse:getY(), horse:getZ()
end

---@param character IsoGameCharacter
---@param horse IsoAnimal
---@return number, number, number
---@nodiscard
HorseUtils.getClosestMount = function(character, horse)
    local lx, ly, lz = HorseUtils.getMountWorld(horse, "mountLeft")
    local rx, ry, rz = HorseUtils.getMountWorld(horse, "mountRight")
    local px, py     = character:getX(), character:getY()

    local dl = (px - lx) * (px - lx) + (py - ly) * (py - ly)
    local dr = (px - rx) * (px - rx) + (py - ry) * (py - ry)

    local tx, ty, tz = lx, ly, lz
    if dr < dl then
        tx, ty, tz = rx, ry, rz
    end

    return tx, ty, tz
end

---@param horse IsoAnimal
---@return fun()
---@return IsoDirections
HorseUtils.lockHorseForInteraction = function(horse)
    if horse.getPathFindBehavior2 then horse:getPathFindBehavior2():reset() end
    if horse.getBehavior then
        local bh = horse:getBehavior()
        bh:setBlockMovement(true)
        bh:setDoingBehavior(false)
    end
    if horse.stopAllMovementNow then horse:stopAllMovementNow() end

    local lockDir = horse:getDir()
    local function lockTick()
        if horse and horse:isExistInTheWorld() then horse:setDir(lockDir) end
    end
    Events.OnTick.Add(lockTick)

    local function unlock()
        Events.OnTick.Remove(lockTick)
        if horse and horse.getBehavior then horse:getBehavior():setBlockMovement(false) end
    end

    return unlock, lockDir
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

---@param template string
---@param params table<string, string>
---@nodiscard
HorseUtils.formatTemplate = function(template, params)
    return template:gsub("{(%w+)}", params)
end

HorseUtils.REINS_MODELS = {
    ["HorseMod.HorseReins_Crude"] = {
        idle = "HorseMod.HorseReins_Crude",
        walking = "HorseMod.HorseReins_Walking_Crude",
        trot = "HorseMod.HorseReins_Troting_Crude",
        gallop = "HorseMod.HorseReins_Running_Crude",
    },
    ["HorseMod.HorseReins_Black"] = {
        idle = "HorseMod.HorseReins_Black",
        walking = "HorseMod.HorseReins_Walking_Black",
        trot = "HorseMod.HorseReins_Troting_Black",
        gallop = "HorseMod.HorseReins_Running_Black",
    },
    ["HorseMod.HorseReins_White"] = {
        idle = "HorseMod.HorseReins_White",
        walking = "HorseMod.HorseReins_Walking_White",
        trot = "HorseMod.HorseReins_Troting_White",
        gallop = "HorseMod.HorseReins_Running_White",
    },
    ["HorseMod.HorseReins_Brown"] = {
        idle = "HorseMod.HorseReins_Brown",
        walking = "HorseMod.HorseReins_Walking_Brown",
        trot = "HorseMod.HorseReins_Troting_Brown",
        gallop = "HorseMod.HorseReins_Running_Brown",
    },
}


return HorseUtils