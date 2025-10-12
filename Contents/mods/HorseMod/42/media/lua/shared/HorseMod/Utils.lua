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

HorseUtils.getMountWorld = function(horse, name)
    if horse.getAttachmentWorldPos then
        local v = horse:getAttachmentWorldPos(name)
        if v then return v:x(), v:y(), v:z() end
    end
    local dx = (name == "mountLeft") and -0.6 or 0.6
    return horse:getX() + dx, horse:getY(), horse:getZ()
end

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
    end

    local ft = saddle:getFullType()

    -- TODO: why are we checking this here? just don't let the animal equip an item that isn't a saddle
    if ft:lower():find("saddle", 1, true) then
        return saddle
    end

    -- FIXME: this doesn't exist ????
    --  this is preferable to the string check !
    -- if HorseMod.SADDLES[ft] then
    --     return saddle 
    -- end
    return nil
end


return HorseUtils