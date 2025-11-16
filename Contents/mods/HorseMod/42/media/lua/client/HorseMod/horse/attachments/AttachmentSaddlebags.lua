local HorseUtils = require("HorseMod/Utils")
local AttachmentUtils = require("HorseMod/horse/attachments/AttachmentUtils")
local AttachmentLocations = require("HorseMod/horse/attachments/AttachmentLocations")


---@class HorseAttachmentSaddlebags
local HorseAttachmentSaddlebags = {}


HorseAttachmentSaddlebags.SADDLEBAG_SLOT = AttachmentLocations.SADDLEBAG_SLOT
HorseAttachmentSaddlebags.SADDLEBAG_FULLTYPE = AttachmentLocations.SADDLEBAG_FULLTYPE
HorseAttachmentSaddlebags.SADDLEBAG_CONTAINER_TYPE = AttachmentLocations.SADDLEBAG_CONTAINER_TYPE

local SADDLEBAG_UPDATE_INTERVAL = 10
local saddlebagTick = 0
local trackedSaddlebags = setmetatable({}, { __mode = "k" })


---@type fun(animal: IsoAnimal)|nil
local dropOnDeathCallback = nil


---@param callback fun(animal: IsoAnimal)
function HorseAttachmentSaddlebags.setDropOnDeathCallback(callback)
    dropOnDeathCallback = callback
end


---@param player IsoPlayer|nil
local function refreshPlayerInventories(player)
    if not player then
        return
    end
    local pdata = getPlayerData(player:getPlayerNum())
    pdata.playerInventory:refreshBackpacks()
    pdata.lootInventory:refreshBackpacks()
    triggerEvent("OnContainerUpdate")
end


---@nodiscard
---@param animal IsoAnimal|nil
---@return HorseSaddlebagData|nil
function HorseAttachmentSaddlebags.getSaddlebagData(animal)
    if not animal then
        return nil
    end
    local md = animal:getModData()
    md.HM_Saddlebags = md.HM_Saddlebags or {}
    return md.HM_Saddlebags
end


---@nodiscard
---@param animal IsoAnimal
---@return HorseSaddlebagData|nil
function HorseAttachmentSaddlebags.enableTracking(animal)
    local data = HorseAttachmentSaddlebags.getSaddlebagData(animal)
    if not data then
        return nil
    end
    data.active = true
    data.missingCount = data.missingCount or 0
    data.lastSpawnTick = data.lastSpawnTick or -99999
    trackedSaddlebags[animal] = true
    return data
end


---@param animal IsoAnimal
---@return HorseSaddlebagData|nil
function HorseAttachmentSaddlebags.disableTracking(animal)
    local data = HorseAttachmentSaddlebags.getSaddlebagData(animal)
    if not data then
        return nil
    end
    data.active = nil
    trackedSaddlebags[animal] = nil
    data.itemId = nil
    data.x, data.y, data.z = nil, nil, nil
    data.equipped = nil
    return data
end


---@nodiscard
---@param animal IsoAnimal
---@param data HorseSaddlebagData|nil
---@return IsoWorldInventoryObject|nil, IsoGridSquare|nil
function HorseAttachmentSaddlebags.findSaddlebagWorldItem(animal, data)
    data = data or HorseAttachmentSaddlebags.getSaddlebagData(animal)
    if not data then
        return nil, nil
    end

    local fullType = HorseAttachmentSaddlebags.SADDLEBAG_CONTAINER_TYPE
    local id = data.itemId

    if data.x and data.y and data.z then
        local wo, sq = AttachmentUtils.findWorldItemOnSquare(data.x, data.y, data.z, fullType, id)
        if wo then
            return wo, sq
        end
    end

    local sq = animal and animal:getSquare() or nil
    if sq then
        local wo, sq2 = AttachmentUtils.findWorldItemOnSquare(sq:getX(), sq:getY(), sq:getZ(), fullType, id)
        if wo then
            return wo, sq2
        end
    end

    if id and data.x and data.y and data.z then
        local cell = getCell and getCell() or nil
        if cell then
            for dx = -1, 1 do
                for dy = -1, 1 do
                    if dx ~= 0 or dy ~= 0 then
                        local wo, sq2 = AttachmentUtils.findWorldItemOnSquare(data.x + dx, data.y + dy, data.z, fullType, id)
                        if wo then
                            return wo, sq2
                        end
                    end
                end
            end
        end
    end

    return nil, sq
end


---@param animal IsoAnimal
---@param item InventoryItem|nil
---@param force boolean|nil
---@return IsoWorldInventoryObject|nil, IsoGridSquare|nil
function HorseAttachmentSaddlebags.spawnSaddlebagContainer(animal, item, force)
    local sq = animal and animal:getSquare() or nil
    local data = HorseAttachmentSaddlebags.getSaddlebagData(animal)

    if data and data.equipped and not item and not force then
        return nil, nil
    end
    if not sq then
        return nil, nil
    end

    local worldObj
    local pdata = getPlayerData and getPlayerData(0) or nil

    if item then
        local container = item:getContainer()
        if container and container.Remove then
            container:Remove(item)
        elseif container and container.DoRemoveItem then
            container:DoRemoveItem(item)
        end
        sq:AddWorldInventoryItem(item, 0.0, 0.0, 0.0)
        worldObj = item:getWorldItem()
        if pdata then
            pdata.playerInventory:refreshBackpacks()
            pdata.lootInventory:refreshBackpacks()
        end
    else
        local newItem = sq:AddWorldInventoryItem(HorseAttachmentSaddlebags.SADDLEBAG_CONTAINER_TYPE, 0.0, 0.0, 0.0)
        if not newItem then
            return nil, nil
        end
        worldObj = newItem:getWorldItem()
        item = newItem
        if pdata then
            pdata.playerInventory:refreshBackpacks()
            pdata.lootInventory:refreshBackpacks()
        end
    end

    local d = HorseAttachmentSaddlebags.enableTracking(animal)
    if d then
        d.x, d.y, d.z = sq:getX(), sq:getY(), sq:getZ()
        d.itemId = item.getID and item:getID() or nil
    end

    return worldObj, sq
end


---@nodiscard
---@param animal IsoAnimal
---@param data HorseSaddlebagData|nil
---@return IsoWorldInventoryObject|nil, IsoGridSquare|nil
function HorseAttachmentSaddlebags.adoptAnySaddlebagWorldItem(animal, data)
    local sq = animal and animal:getSquare() or nil
    if not sq then
        return nil, nil
    end

    local hx, hy, hz = sq:getX(), sq:getY(), sq:getZ()

    local wo, s = AttachmentUtils.findWorldItemOnSquare(hx, hy, hz, HorseAttachmentSaddlebags.SADDLEBAG_CONTAINER_TYPE, nil)
    if wo then
        return wo, s
    end

    if data and data.x and data.y and data.z then
        wo, s = AttachmentUtils.findWorldItemOnSquare(data.x, data.y, data.z, HorseAttachmentSaddlebags.SADDLEBAG_CONTAINER_TYPE, nil)
        if wo then
            return wo, s
        end
        for dx = -1, 1 do
            for dy = -1, 1 do
                if dx ~= 0 or dy ~= 0 then
                    wo, s = AttachmentUtils.findWorldItemOnSquare(data.x + dx, data.y + dy, data.z, HorseAttachmentSaddlebags.SADDLEBAG_CONTAINER_TYPE, nil)
                    if wo then
                        return wo, s
                    end
                end
            end
        end
    end
    return nil, sq
end


---@param animal IsoAnimal
function HorseAttachmentSaddlebags.moveSaddlebagContainer(animal)
    local data = HorseAttachmentSaddlebags.getSaddlebagData(animal)
    if not data or not data.active then
        return
    end
    if not HorseUtils.isHorse(animal) then
        return
    end

    data.missingCount = data.missingCount or 0
    data.lastSpawnTick = data.lastSpawnTick or 0

    local sq = animal:getSquare()
    if not sq then
        return
    end

    local hx, hy, hz = sq:getX(), sq:getY(), sq:getZ()

    local worldObj, curSq = HorseAttachmentSaddlebags.findSaddlebagWorldItem(animal, data)

    if not worldObj then
        local adoptWO, adoptSq = HorseAttachmentSaddlebags.adoptAnySaddlebagWorldItem(animal, data)
        if adoptWO then
            worldObj, curSq = adoptWO, adoptSq
            local it = worldObj:getItem()
            if it then
                data.itemId = it:getID()
            end
        end
    end

    if not worldObj then
        data.missingCount = (data.missingCount or 0) + 1
        return
    end

    data.missingCount = 0

    local cx = curSq and curSq:getX() or nil
    local cy = curSq and curSq:getY() or nil
    local cz = curSq and curSq:getZ() or nil
    if cx ~= hx or cy ~= hy or cz ~= hz then
        local item = worldObj:getItem()
        if item then
            if worldObj.removeFromSquare then
                worldObj:removeFromSquare()
            end
            if worldObj.removeFromWorld then
                worldObj:removeFromWorld()
            end
            sq:AddWorldInventoryItem(item, 0.0, 0.0, 0.0)
            worldObj = item:getWorldItem() or worldObj
        end
    end

    data.x, data.y, data.z = hx, hy, hz
    local item = worldObj:getItem()
    if item then
        data.itemId = item:getID()
    end
end


---@param animal IsoAnimal
---@param player IsoPlayer|nil
---@param allowInitialSpawn boolean|nil
function HorseAttachmentSaddlebags.ensureSaddlebagContainer(animal, player, allowInitialSpawn)
    local data = HorseAttachmentSaddlebags.enableTracking(animal)
    if not data then
        return
    end

    local worldObj = HorseAttachmentSaddlebags.findSaddlebagWorldItem(animal, data)
    if worldObj then
        HorseAttachmentSaddlebags.moveSaddlebagContainer(animal)
        return
    end

    if allowInitialSpawn then
        HorseAttachmentSaddlebags.spawnSaddlebagContainer(animal, nil, true)
        local d = HorseAttachmentSaddlebags.getSaddlebagData(animal)
        if d then
            d.equipped = true
        end
        data.missingCount = 0
        data.lastSpawnTick = saddlebagTick
    end
end


---@param player IsoPlayer|nil
---@param animal IsoAnimal
function HorseAttachmentSaddlebags.removeSaddlebagContainer(player, animal)
    local data = HorseAttachmentSaddlebags.getSaddlebagData(animal)
    if not data then
        return
    end

    local worldObj, sq = HorseAttachmentSaddlebags.findSaddlebagWorldItem(animal, data)
    local item = worldObj and worldObj:getItem()
    if worldObj then
        if worldObj.removeFromSquare then
            worldObj:removeFromSquare()
        end
        if worldObj.removeFromWorld then
            worldObj:removeFromWorld()
        end
    elseif not item and sq then
        local list = sq:getWorldObjects()
        if list then
            for i = 0, list:size() - 1 do
                local wo = list:get(i)
                local it = wo and wo:getItem()
                if it and it:getFullType() == HorseAttachmentSaddlebags.SADDLEBAG_CONTAINER_TYPE then
                    if not data.itemId or (it.getID and it:getID() == data.itemId) then
                        item = it
                        if wo.removeFromSquare then
                            wo:removeFromSquare()
                        end
                        if wo.removeFromWorld then
                            wo:removeFromWorld()
                        end
                        break
                    end
                end
            end
        end
    end

    if item then
        AttachmentUtils.giveBackToPlayerOrDrop(player, animal, item)
        refreshPlayerInventories(player)
    end

    HorseAttachmentSaddlebags.disableTracking(animal)
end


---@nodiscard
---@param animal IsoAnimal
---@return InventoryItem|nil, ItemContainer|nil
function HorseAttachmentSaddlebags.getVisibleSaddlebagsItem(animal)
    local it = AttachmentUtils.getAttachedItem(animal, HorseAttachmentSaddlebags.SADDLEBAG_SLOT)
    if it and it:IsInventoryContainer() then
        return it, it:getItemContainer()
    end
    return nil, nil
end


---@nodiscard
---@param animal IsoAnimal
---@return IsoWorldInventoryObject|nil, IsoGridSquare|nil, ItemContainer|nil
function HorseAttachmentSaddlebags.getInvisibleSaddlebags(animal)
    local data = HorseAttachmentSaddlebags.getSaddlebagData(animal)
    if not data then
        return nil, nil, nil
    end
    local wo, sq = HorseAttachmentSaddlebags.findSaddlebagWorldItem(animal, data)
    if not wo then
        return nil, nil, nil
    end
    local it = wo:getItem()
    if not (it and it:IsInventoryContainer()) then
        return nil, nil, nil
    end
    return wo, sq, it:getItemContainer()
end


---@nodiscard
---@param itemContainer ItemContainer|nil
---@return InventoryItem[]
local function copyItemsToTable(itemContainer)
    local out = {}
    if not itemContainer then
        return out
    end
    local list = itemContainer:getItems()
    if list then
        for i = 0, list:size() - 1 do
            table.insert(out, list:get(i))
        end
    end
    return out
end


---@param character IsoGameCharacter|IsoPlayer
---@param srcCont ItemContainer|nil
---@param dstCont ItemContainer|nil
---@param dropSq IsoGridSquare|nil
local function transferAll(character, srcCont, dstCont, dropSq)
    if not (srcCont and dstCont) then
        return
    end
    local toMove = copyItemsToTable(srcCont)
    for i = 1, #toMove do
        local it = toMove[i]
        if it and it:getContainer() == srcCont then
            ISTransferAction:transferItem(character, it, srcCont, dstCont, dropSq)
        end
    end
end


---@param player IsoPlayer
---@param animal IsoAnimal
function HorseAttachmentSaddlebags.moveVisibleToInvisibleOnAttach(player, animal)
    local visItem, visCont = HorseAttachmentSaddlebags.getVisibleSaddlebagsItem(animal)
    if not visCont then
        return
    end
    local wo, sq, invisCont = HorseAttachmentSaddlebags.getInvisibleSaddlebags(animal)
    if not invisCont then
        return
    end
    transferAll(player, visCont, invisCont, nil)
    refreshPlayerInventories(player)
end


---@param player IsoPlayer|nil
---@param animal IsoAnimal
function HorseAttachmentSaddlebags.moveInvisibleToVisibleThenRemove(player, animal)
    local visItem, visCont = HorseAttachmentSaddlebags.getVisibleSaddlebagsItem(animal)
    local wo, sq, invisCont = HorseAttachmentSaddlebags.getInvisibleSaddlebags(animal)

    if invisCont and visCont and player then
        transferAll(player, invisCont, visCont, nil)
    end

    if wo and sq then
        sq:transmitRemoveItemFromSquare(wo)
        wo:removeFromWorld()
        wo:removeFromSquare()
        wo:setSquare(nil)
    end
    HorseAttachmentSaddlebags.disableTracking(animal)
    refreshPlayerInventories(player)
end


local function updateTrackedSaddlebags()
    saddlebagTick = saddlebagTick + 1
    if saddlebagTick % SADDLEBAG_UPDATE_INTERVAL ~= 0 then
        return
    end

    for animal in pairs(trackedSaddlebags) do
        if not animal or (animal.isRemovedFromWorld and animal:isRemovedFromWorld()) or not HorseUtils.isHorse(animal) then
            trackedSaddlebags[animal] = nil
        elseif (animal.isDead and animal:isDead()) then
            local md = animal:getModData()
            local already = md and md.HM_Attach and md.HM_Attach.DroppedOnDeath
            if not already and dropOnDeathCallback then
                dropOnDeathCallback(animal)
            end
            trackedSaddlebags[animal] = nil
        else
            local data = HorseAttachmentSaddlebags.getSaddlebagData(animal)
            if data and data.active then
                HorseAttachmentSaddlebags.moveSaddlebagContainer(animal)
            else
                trackedSaddlebags[animal] = nil
            end
        end
    end
end

local function hideInvisSaddlebagsFromContext(player, context, worldobjects, test)
    if test then return end

    local hide = false
    for _, obj in ipairs(worldobjects) do
        if instanceof(obj, "IsoWorldInventoryObject") then
            local item = obj:getItem()
            if item and item:getFullType() == "HorseMod.HorseSaddleBagsContainer" then
                hide = true
                break
            end
        end
    end
    if not hide then return end

    local grabName = getText("ContextMenu_Grab")
    context:removeOptionByName(grabName)
    local extendedPlacementName = getText("ContextMenu_ExtendedPlacement")
    context:removeOptionByName(extendedPlacementName)
end

Events.OnFillWorldObjectContextMenu.Add(hideInvisSaddlebagsFromContext)

Events.OnTick.Add(updateTrackedSaddlebags)

return HorseAttachmentSaddlebags
