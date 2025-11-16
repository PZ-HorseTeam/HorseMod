---@class HorseAttachmentUtils
local HorseAttachmentUtils = {}


---@nodiscard
---@param animal IsoAnimal
---@param slot string|HorseAttachmentItemDefinition
---@return InventoryItem|nil
function HorseAttachmentUtils.getAttachedItem(animal, slot)
    if animal.getAttachedItems then
        local ai = animal:getAttachedItems()
        if ai then
            return ai:getItem(slot)
        end
    end
    if animal.getAttachedItem then
        return animal:getAttachedItem(slot)
    end
    return nil
end


---@param animal IsoAnimal
---@param slot string|HorseAttachmentItemDefinition
---@param item InventoryItem|nil
function HorseAttachmentUtils.setAttachedItem(animal, slot, item)
    animal:setAttachedItem(slot, item)
end


---@param player IsoPlayer|nil
---@param animal IsoAnimal
---@param item InventoryItem|nil
function HorseAttachmentUtils.giveBackToPlayerOrDrop(player, animal, item)
    if not item then
        return
    end
    local pinv = player and player:getInventory()
    if pinv and pinv:addItem(item) then
        return
    end
    local sq = animal:getSquare() or (player and player:getSquare())
    if sq then
        sq:AddWorldInventoryItem(item, 0.0, 0.0, 0.0)
    end
end


---@nodiscard
---@param player IsoPlayer
---@param itemsMap HorseAttachmentItemsMap
---@return InventoryItem[]
function HorseAttachmentUtils.collectCandidateItems(player, itemsMap)
    local out = {}

    local function addIfListed(item)
        if not item then
            return
        end
        local ft = item:getFullType()
        if itemsMap[ft] then
            table.insert(out, item)
        end
    end

    local pinv = player and player:getInventory() or nil
    if pinv and pinv.getAllEvalRecurse then
        local list = ArrayList.new()
        pinv:getAllEvalRecurse(function(it)
            return itemsMap[it:getFullType()] ~= nil
        end, list)
        for i = 0, list:size() - 1 do
            addIfListed(list:get(i))
        end
    elseif pinv and pinv.getItems then
        local its = pinv:getItems()
        for i = 0, its:size() - 1 do
            addIfListed(its:get(i))
        end
    end

    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.getContainers then
        local containers = ISInventoryPaneContextMenu.getContainers(player)
        for i = 0, containers:size() - 1 do
            local cont = containers[i]
            if cont and cont:getType() == "floor" then
                local its = cont:getItems()
                if its then
                    for j = 0, its:size() - 1 do
                        addIfListed(its:get(j))
                    end
                end
            end
        end
    end

    return out
end


---@param animal IsoAnimal
---@return table<string, string>, table<string, HorseAttachmentGroundData>
function HorseAttachmentUtils.ensureHorseModData(animal)
    local md = animal:getModData()
    md.HM_Attach = md.HM_Attach or { bySlot = {}, ground = {} }
    md.HM_Attach.bySlot = md.HM_Attach.bySlot or {}
    md.HM_Attach.ground = md.HM_Attach.ground or {}
    return md.HM_Attach.bySlot, md.HM_Attach.ground
end


---@nodiscard
---@param x number
---@param y number
---@param z number
---@return IsoGridSquare|nil, ArrayList|nil
function HorseAttachmentUtils.getWorldInventoryObjectsAt(x, y, z)
    local sq = getCell():getGridSquare(math.floor(x), math.floor(y), z)
    if not sq then
        return nil, nil
    end
    return sq, sq:getWorldObjects() or nil
end


---@nodiscard
---@param x number
---@param y number
---@param z number
---@param fullType string
---@param wantId integer|nil
---@return IsoWorldInventoryObject|nil, IsoGridSquare|nil
function HorseAttachmentUtils.findWorldItemOnSquare(x, y, z, fullType, wantId)
    local sq, list = HorseAttachmentUtils.getWorldInventoryObjectsAt(x, y, z)
    if not list then
        return nil, sq
    end
    for i = 0, list:size() - 1 do
        local wo = list:get(i)
        if wo and wo.getItem then
            local it = wo:getItem()
            if it and it:getFullType() == fullType then
                if not wantId or (it.getID and it:getID() == wantId) then
                    return wo, sq
                end
            end
        end
    end
    return nil, sq
end


---@nodiscard
---@param worldObj IsoWorldInventoryObject|nil
---@param sq IsoGridSquare|nil
---@param inv ItemContainer|nil
---@return InventoryItem|nil
function HorseAttachmentUtils.takeWorldItemToInventory(worldObj, sq, inv)
    if not (worldObj and worldObj.getItem and inv) then
        return nil
    end
    local item = worldObj:getItem()
    if not item then
        return nil
    end
    inv:AddItem(item)
    if worldObj.removeFromSquare then
        worldObj:removeFromSquare()
    elseif sq and sq.transmitRemoveItemFromSquare then
        sq:transmitRemoveItemFromSquare(worldObj)
    elseif sq and sq.RemoveWorldObject then
        sq:RemoveWorldObject(worldObj)
    end
    return item
end

return HorseAttachmentUtils
