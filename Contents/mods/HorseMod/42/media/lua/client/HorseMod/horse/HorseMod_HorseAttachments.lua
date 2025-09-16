require "ISUI/Animal/ISAnimalContextMenu"

local HorseUtils = require("HorseMod/HorseMod_Utils")
HorseMod = HorseMod or {}
HorseMod.HorseAttachments  = HorseMod.HorseAttachments

-----------------------------------------------------------------------
-- Attachment locations setup
-----------------------------------------------------------------------
local group = AttachedLocations.getGroup("Animal")

local saddle = group:getOrCreateLocation("Saddle")
saddle:setAttachmentName("saddle")

local saddlebags = group:getOrCreateLocation("Saddlebags")
saddlebags:setAttachmentName("saddlebags")

local head = group:getOrCreateLocation("Head")
head:setAttachmentName("head")

local mountLeft = group:getOrCreateLocation("MountLeft")
mountLeft:setAttachmentName("mountLeft")

local mountRight = group:getOrCreateLocation("MountRight")
mountRight:setAttachmentName("mountRight")


-- Known slots list
local SLOTS = { "Saddle", "Saddlebags", "Head", "MountLeft", "MountRight" }

local SADDLEBAG_SLOT = "Saddlebags"
local SADDLEBAG_FULLTYPE = "HorseMod.HorseSaddleBags"
local SADDLEBAG_CONTAINER_TYPE = "HorseMod.HorseSaddleBagsContainer"

HorseMod.HorseAttachments = HorseMod.HorseAttachments or {
    --EXAMPLE: ["FullType"] = { slot = "AttachmentSlot" }
    ["HorseMod.HorseSaddle"] = { slot = "Saddle" },
    ["HorseMod.HorseBackpack"] = { slot = "Saddle" },
    ["HorseMod.HorseSaddleBags"] = { slot = "Saddlebags" },
}

-----------------------------------------------------------------------
-- Utils
-----------------------------------------------------------------------
local function getTextOr(s) return (getTextOrNull and (getTextOrNull(s) or s)) or s end

local function getAttachedItem(animal, slot)
    if animal.getAttachedItems then
        local ai = animal:getAttachedItems()
        if ai and ai.getItem then return ai:getItem(slot) end
    end
    if animal.getAttachedItem then
        return animal:getAttachedItem(slot)
    end
    return nil
end

local function setAttachedItem(animal, slot, item)
    animal:setAttachedItem(slot, item)
end

local function giveBackToPlayerOrDrop(player, animal, item)
    if not item then return end
    local pinv = player and player:getInventory()
    if pinv and pinv:addItem(item) then return end
    local sq = animal:getSquare() or (player and player:getSquare())
    if sq then sq:AddWorldInventoryItem(item, 0.0, 0.0, 0.0) end
end

local function collectCandidateItems(player, itemsMap)
    local out = {}

    local function addIfListed(item)
        if not item then return end
        local ft = item:getFullType()
        if itemsMap[ft] then table.insert(out, item) end
    end

    local pinv = player and player:getInventory()
    if pinv and pinv.getAllEvalRecurse then
        local list = ArrayList.new()
        pinv:getAllEvalRecurse(function(it) return itemsMap[it:getFullType()] ~= nil end, list)
        for i=0, list:size()-1 do addIfListed(list:get(i)) end
    else
        if pinv and pinv.getItems then
            local its = pinv:getItems()
            for i=0, its:size()-1 do addIfListed(its:get(i)) end
        end
    end

    if ISInventoryPaneContextMenu and ISInventoryPaneContextMenu.getContainers then
        local containers = ISInventoryPaneContextMenu.getContainers(player)
        for i=0, containers:size()-1 do
            local cont = containers[i]
            if cont and cont:getType() == "floor" then
                local its = cont:getItems()
                if its then
                    for j=0, its:size()-1 do addIfListed(its:get(j)) end
                end
            end
        end
    end

    return out
end

local function ensureHorseModData(animal)
    local md = animal:getModData()
    md.HM_Attach = md.HM_Attach or { bySlot = {}, ground = {} }
    md.HM_Attach.bySlot  = md.HM_Attach.bySlot  or {}
    md.HM_Attach.ground  = md.HM_Attach.ground  or {}
    return md.HM_Attach.bySlot, md.HM_Attach.ground
end

local function getWorldInventoryObjectsAt(x, y, z)
    local sq = getCell():getGridSquare(math.floor(x), math.floor(y), z)
    return sq, sq and sq:getWorldObjects() or nil
end

local function findWorldItemOnSquare(x, y, z, fullType, wantId)
    local sq, list = getWorldInventoryObjectsAt(x, y, z)
    if not list then return nil, nil end
    for i=0, list:size()-1 do
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

local function takeWorldItemToInventory(worldObj, sq, inv)
    if not (worldObj and worldObj.getItem and inv) then return nil end
    local item = worldObj:getItem()
    if not item then return nil end
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

-----------------------------------------------------------------------
-- Saddlebags container support
-----------------------------------------------------------------------
local SADDLEBAG_UPDATE_INTERVAL = 10
local saddlebagTick = 0
local _trackedSaddlebagHorses = setmetatable({}, { __mode = "k" })

local function refreshPlayerInventories(player)
    if not player then return end
    if triggerEvent then triggerEvent("OnContainerUpdate") end
    if not getPlayerData then return end
    local pdata = getPlayerData(player:getPlayerNum())
    if not pdata then return end
    if pdata.playerInventory and pdata.playerInventory.refreshBackpacks then
        pdata.playerInventory:refreshBackpacks()
    end
    if pdata.lootInventory and pdata.lootInventory.refreshBackpacks then
        pdata.lootInventory:refreshBackpacks()
    end
end

local function getSaddlebagData(animal)
    if not animal or not animal.getModData then return nil end
    local md = animal:getModData()
    md.HM_Saddlebags = md.HM_Saddlebags or {}
    return md.HM_Saddlebags
end

local function enableSaddlebagTracking(animal)
    local data = getSaddlebagData(animal)
    if not data then return nil end
    data.active = true
    data.missingCount  = data.missingCount or 0
    data.lastSpawnTick = data.lastSpawnTick or -99999
    _trackedSaddlebagHorses[animal] = true
    return data
end

local function disableSaddlebagTracking(animal)
    local data = getSaddlebagData(animal)
    if not data then return nil end
    data.active = nil
    _trackedSaddlebagHorses[animal] = nil
    data.itemId = nil
    data.x, data.y, data.z = nil, nil, nil
    data.equipped = nil       -- ← clear the flag
    return data
end

local function findSaddlebagWorldItem(animal, data)
    data = data or getSaddlebagData(animal)
    if not data then return nil, nil end

    local fullType = SADDLEBAG_CONTAINER_TYPE
    local id = data.itemId

    if data.x and data.y and data.z then
        local wo, sq = findWorldItemOnSquare(data.x, data.y, data.z, fullType, id)
        if wo then return wo, sq end
    end

    local sq = animal and animal:getSquare() or nil
    if sq then
        local wo, sq2 = findWorldItemOnSquare(sq:getX(), sq:getY(), sq:getZ(), fullType, id)
        if wo then return wo, sq2 end
    end

    if id and data.x and data.y and data.z then
        local cell = getCell and getCell()
        if cell then
            for dx = -1, 1 do
                for dy = -1, 1 do
                    if dx ~= 0 or dy ~= 0 then
                        local wo, sq2 = findWorldItemOnSquare(data.x + dx, data.y + dy, data.z, fullType, id)
                        if wo then return wo, sq2 end
                    end
                end
            end
        end
    end

    return nil, sq
end

local function isInvContainerEmpty(item)
    if not item then return true end
    if item.IsInventoryContainer and item:IsInventoryContainer() then
        local c = item.getItemContainer and item:getItemContainer() or nil
        return (not c) or c:isEmpty()
    end
    return true
end

local function tryRemoveSaddlebagContainer(player, animal)
    local data = getSaddlebagData(animal)
    if not data then return true end

    local worldObj, sq = findSaddlebagWorldItem(animal, data)
    local invItem = worldObj and worldObj:getItem() or nil

    if invItem and invItem:IsInventoryContainer() then
        if not isInvContainerEmpty(invItem) then
            if player and player.Say then
                player:Say(getText("IGUI_Horse_SaddlebagNotEmpty") or "I should empty the saddlebags first.")
            end
            return false
        end
        if worldObj.removeFromSquare then worldObj:removeFromSquare() end
        if worldObj.removeFromWorld then worldObj:removeFromWorld() end
        disableSaddlebagTracking(animal)
        refreshPlayerInventories(player)
        return true
    end

    local inv = animal and animal:getInventory() or nil
    if inv then
        local stray = inv:FindAndReturn(SADDLEBAG_CONTAINER_TYPE)
        if stray then
            if not isInvContainerEmpty(stray) then
                if player and player.Say then
                    player:Say(getText("IGUI_Horse_SaddlebagNotEmpty") or "I should empty the saddlebags first.")
                end
                return false
            end
            inv:Remove(stray)
        end
    end

    disableSaddlebagTracking(animal)
    return true
end

local function takeSaddlebagContainerFromPlayer(player)
    if not player then return nil end
    local inv = player:getInventory()
    if not inv then return nil end

    local item = nil
    if inv.getAllEvalRecurse then
        local list = ArrayList.new()
        inv:getAllEvalRecurse(function(it) return it:getFullType() == SADDLEBAG_FULLTYPE end, list)
        if list and list:size() > 0 then
            item = list:get(0)
        end
    end

    if not item and inv.FindAndReturn then
        item = inv:FindAndReturn(SADDLEBAG_FULLTYPE)
    end

    if not item then return nil end

    local container = item.getContainer and item:getContainer() or nil
    if container and container.Remove then
        container:Remove(item)
    elseif container and container.DoRemoveItem then
        container:DoRemoveItem(item)
    end

    refreshPlayerInventories(player)

    return item
end

local function spawnSaddlebagContainer(animal, item, force)
    local sq = animal and animal:getSquare() or nil
    local data = getSaddlebagData(animal)

    if data and data.equipped and not item and not force then
        return nil, nil
    end
    if not sq then return nil, nil end

    local worldObj
    local pdata = getPlayerData and getPlayerData(0) or nil

    if item then
        local container = item.getContainer and item:getContainer() or nil
        if container and container.Remove then container:Remove(item)
        elseif container and container.DoRemoveItem then container:DoRemoveItem(item) end
        sq:AddWorldInventoryItem(item, 0.0, 0.0, 0.0)
        worldObj = item:getWorldItem()
        if pdata and pdata.playerInventory then
            pdata.playerInventory:refreshBackpacks()
            if pdata.lootInventory then pdata.lootInventory:refreshBackpacks() end
        end
    else
        local newItem = sq:AddWorldInventoryItem(SADDLEBAG_CONTAINER_TYPE, 0.0, 0.0, 0.0)
        if not newItem then return nil, nil end
        worldObj = newItem:getWorldItem()
        item = newItem
        if pdata and pdata.playerInventory then
            pdata.playerInventory:refreshBackpacks()
            if pdata.lootInventory then pdata.lootInventory:refreshBackpacks() end
        end
    end

    local d = enableSaddlebagTracking(animal)
    if d then
        d.x, d.y, d.z = sq:getX(), sq:getY(), sq:getZ()
        d.itemId = item.getID and item:getID() or nil
    end

    return worldObj, sq
end

local function adoptAnySaddlebagWorldItem(animal, data)
    local sq = animal and animal:getSquare() or nil
    if not sq then return nil, nil end

    local hx, hy, hz = sq:getX(), sq:getY(), sq:getZ()

    local wo, s = findWorldItemOnSquare(hx, hy, hz, SADDLEBAG_CONTAINER_TYPE, nil)
    if wo then return wo, s end

    if data and data.x and data.y and data.z then
        wo, s = findWorldItemOnSquare(data.x, data.y, data.z, SADDLEBAG_CONTAINER_TYPE, nil)
        if wo then return wo, s end
        for dx=-1,1 do
            for dy=-1,1 do
                if dx ~= 0 or dy ~= 0 then
                    wo, s = findWorldItemOnSquare(data.x + dx, data.y + dy, data.z, SADDLEBAG_CONTAINER_TYPE, nil)
                    if wo then return wo, s end
                end
            end
        end
    end
    return nil, sq
end

local function moveSaddlebagContainer(animal)
    local data = getSaddlebagData(animal)
    if not data or not data.active then return end
    if not HorseUtils.isHorse(animal) then return end

    data.missingCount  = data.missingCount or 0
    data.lastSpawnTick = data.lastSpawnTick or -99999

    local sq = animal:getSquare()
    if not sq then return end

    local hx, hy, hz = sq:getX(), sq:getY(), sq:getZ()

    local worldObj, curSq = findSaddlebagWorldItem(animal, data)

    if not worldObj then
        local adoptWO, adoptSq = adoptAnySaddlebagWorldItem(animal, data)
        if adoptWO then
            worldObj, curSq = adoptWO, adoptSq
            local it = worldObj:getItem()
            if it and it.getID then data.itemId = it:getID() end
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
            if worldObj.removeFromSquare then worldObj:removeFromSquare() end
            if worldObj.removeFromWorld then worldObj:removeFromWorld() end
            sq:AddWorldInventoryItem(item, 0.0, 0.0, 0.0)
            worldObj = item:getWorldItem() or worldObj
        end
    end

    data.x, data.y, data.z = hx, hy, hz
    local item = worldObj:getItem()
    if item and item.getID then
        data.itemId = item:getID()
    end
end

local function ensureSaddlebagContainer(animal, player, allowInitialSpawn)
    local data = enableSaddlebagTracking(animal)
    if not data then return end

    local worldObj = findSaddlebagWorldItem(animal, data)
    if worldObj then
        moveSaddlebagContainer(animal)
        return
    end

    if allowInitialSpawn then
        spawnSaddlebagContainer(animal, nil, true)  -- force = true (see §2)
        local d = getSaddlebagData(animal); if d then d.equipped = true end
        data.missingCount  = 0
        data.lastSpawnTick = saddlebagTick
        return
    end

    local fromPlayer = player and takeSaddlebagContainerFromPlayer(player) or nil
    if fromPlayer then
        spawnSaddlebagContainer(animal, fromPlayer, true)
        local d = getSaddlebagData(animal); if d then d.equipped = true end
        data.missingCount  = 0
        data.lastSpawnTick = saddlebagTick
    end
end

local function removeSaddlebagContainer(player, animal)
    local data = getSaddlebagData(animal)
    if not data then return end

    local worldObj, sq = findSaddlebagWorldItem(animal, data)
    local item = worldObj and worldObj:getItem() or nil
    if worldObj then
        if worldObj.removeFromSquare then worldObj:removeFromSquare() end
        if worldObj.removeFromWorld then worldObj:removeFromWorld() end
    elseif not item and sq and sq.getWorldObjects then
        local list = sq:getWorldObjects()
        if list then
            for i = 0, list:size() - 1 do
                local wo = list:get(i)
                local it = wo and wo:getItem() or nil
                if it and it:getFullType() == SADDLEBAG_CONTAINER_TYPE then
                    if not data.itemId or (it.getID and it:getID() == data.itemId) then
                        item = it
                        if wo.removeFromSquare then wo:removeFromSquare() end
                        if wo.removeFromWorld then wo:removeFromWorld() end
                        break
                    end
                end
            end
        end
    end

    if item then
        giveBackToPlayerOrDrop(player, animal, item)
        refreshPlayerInventories(player)
    end

    disableSaddlebagTracking(animal)
end

local function updateTrackedSaddlebags()
    saddlebagTick = saddlebagTick + 1
    if saddlebagTick % SADDLEBAG_UPDATE_INTERVAL ~= 0 then return end

    for animal in pairs(_trackedSaddlebagHorses) do
        if not animal or (animal.isRemovedFromWorld and animal:isRemovedFromWorld()) or (animal.isDead and animal:isDead()) or not HorseUtils.isHorse(animal) then
            _trackedSaddlebagHorses[animal] = nil
        else
            local data = getSaddlebagData(animal)
            if data and data.active then
                moveSaddlebagContainer(animal)
            else
                _trackedSaddlebagHorses[animal] = nil
            end
        end
    end
end

Events.OnTick.Add(updateTrackedSaddlebags)


-----------------------------------------------------------------------
-- Equip / Unequip
-----------------------------------------------------------------------
local function equipAttachment(player, animal, item, itemsMap)
    local ft   = item:getFullType()
    local def  = itemsMap[ft]
    if not def then return end
    local slot = (type(def) == "table") and def.slot or def

    -- Move to horse inventory and replace if needed
    local inv = animal:getInventory()
    if item:getContainer() ~= inv then
        local oldC = item:getContainer()
        if oldC then oldC:Remove(item) end
        inv:AddItem(item)
    end

    local old = getAttachedItem(animal, slot)
    if old and old ~= item then
        if slot == SADDLEBAG_SLOT and old:getFullType() == SADDLEBAG_FULLTYPE then
            removeSaddlebagContainer(player, animal)
        end
        setAttachedItem(animal, slot, nil)
        giveBackToPlayerOrDrop(player, animal, old)
    end

    setAttachedItem(animal, slot, item)

    local bySlot, ground = ensureHorseModData(animal)
    bySlot[slot] = ft
    ground[slot] = nil

    if slot == SADDLEBAG_SLOT then
    if ft == SADDLEBAG_FULLTYPE then
        ensureSaddlebagContainer(animal, player, true)
        local d = getSaddlebagData(animal); if d then d.equipped = true end
    else
        local d = getSaddlebagData(animal); if d then d.equipped = false end
        removeSaddlebagContainer(player, animal)
    end
end
end

local function unequipAttachment(player, animal, slot)
    local cur = getAttachedItem(animal, slot)
    if not cur then return end
    if slot == SADDLEBAG_SLOT then
        if not tryRemoveSaddlebagContainer(player, animal) then return end
        local d = getSaddlebagData(animal); if d then d.equipped = false end
    end

    setAttachedItem(animal, slot, nil)

    local bySlot, ground = ensureHorseModData(animal)
    bySlot[slot] = nil
    ground[slot] = nil

    giveBackToPlayerOrDrop(player, animal, cur)
end


local function unequipAll(player, animal)
    for i = 1, #SLOTS do
        local slot = SLOTS[i]
        unequipAttachment(player, animal, slot)
    end
end

local function queueHorseGearAction(player, horse, workFn, maxTime, context)
    local unlock, lockDir = HorseUtils.lockHorseForInteraction(horse)
    context:closeAll()

    local lx, ly, lz = HorseUtils.getMountWorld(horse, "mountLeft")
    local rx, ry, rz = HorseUtils.getMountWorld(horse, "mountRight")
    local px, py     = player:getX(), player:getY()

    local dl = (px - lx) * (px - lx) + (py - ly) * (py - ly)
    local dr = (px - rx) * (px - rx) + (py - ry) * (py - ry)

    local tx, ty, tz = lx, ly, lz
    if dr < dl then tx, ty, tz = rx, ry, rz end

    local path
    if ISPathFindAction and ISPathFindAction.pathToLocationF then
        path = ISPathFindAction:pathToLocationF(player, tx, ty, tz)
    end

    local function cleanupOnFail()
        unlock()
    end

    if path then
        path:setOnFail(cleanupOnFail)
        path.stop = function(self)
            cleanupOnFail()
            ISPathFindAction.stop(self)
        end
        path:setOnComplete(function()
            player:setDir(lockDir)
            ISTimedActionQueue.add(ISHorseGearAction:new(player, horse, workFn, maxTime, unlock))
        end)
        ISTimedActionQueue.add(path)
    else
        ISTimedActionQueue.add(ISHorseGearAction:new(player, horse, workFn, maxTime, unlock))
    end
end

-----------------------------------------------------------------------
-- Context menu added to animal context menu
-----------------------------------------------------------------------
local function addAttachmentOptions(playerNum, context, animals, test)
    if test or not animals or #animals == 0 then return end

    local animal = animals[1]
    if not HorseUtils.isHorse(animal) then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local horseOption = context:getOptionFromName(animal:getFullName())
    if not horseOption or not horseOption.subOption then return end

    local horseSubMenu = context:getSubMenu(horseOption.subOption)
    if not horseSubMenu then return end

    local itemsMap = HorseMod.HorseAttachments or {}

    local function slotFor(fullType)
        local def = itemsMap[fullType]
        if def == nil then return nil end
        local t = type(def)
        if t == "string" then
            return def
        elseif t == "table" then
            return def.slot
        end
        return nil
    end

    local function T(s) return (getTextOr and getTextOr(s)) or s end

    -------------------------------------------------------------------
    -- Gear submenu
    -------------------------------------------------------------------
    local gearRoot = horseSubMenu:addOption(T("Gear"))
    local gearSub  = ISContextMenu:getNew(context)
    context:addSubMenu(gearRoot, gearSub)

    -------------------------------------------------------------------
    -- Equip submenu
    -------------------------------------------------------------------
    local candidates = collectCandidateItems(player, itemsMap)
    if #candidates > 0 then
        table.sort(candidates, function(a, b)
            local da = a:getDisplayName() or a:getFullType() or ""
            local db = b:getDisplayName() or b:getFullType() or ""
            if da == db then return a:getFullType() < b:getFullType() end
            return da:lower() < db:lower()
        end)

        local equipRoot = gearSub:addOption(T("Equip"))
        local equipSub  = ISContextMenu:getNew(context)
        context:addSubMenu(equipRoot, equipSub)

        for i = 1, #candidates do
            local it = candidates[i]
            local fullType = it:getFullType()
            local slot     = slotFor(fullType)
            if slot and slot ~= "" then
                local current     = getAttachedItem(animal, slot)
                local currentName = current and (current:getDisplayName() or slot)
                local name        = it:getDisplayName() or fullType
                local label       = current
                    and string.format(T("Replace %s with %s"), currentName, name)
                    or  string.format(T("Equip %s"), name)

                local opt = equipSub:addOption(label, player, function(p, a, obj)
                    queueHorseGearAction(p, a, function()
                        equipAttachment(p, a, obj, itemsMap)
                    end, 120, context)
                end, animal, it)

                opt.toolTip = ISWorldObjectContextMenu.addToolTip()
                opt.toolTip.description = string.format("%s: %s", T("Slot"), tostring(slot))
            end
        end
    else
        local noOpt = gearSub:addOption(T("No compatible gear found"))
        noOpt.notAvailable = true
        if noOpt.setEnabled then noOpt:setEnabled(false) end
    end

    -------------------------------------------------------------------
    -- Unequip submenu
    -------------------------------------------------------------------
    local anyEquipped = false
    for i = 1, #SLOTS do
        local slot = SLOTS[i]
        if getAttachedItem(animal, slot) then anyEquipped = true; break end
    end

    if anyEquipped then
        local uneqRoot = gearSub:addOption(T("Unequip"))
        local uneqSub  = ISContextMenu:getNew(context)
        context:addSubMenu(uneqRoot, uneqSub)

        for i = 1, #SLOTS do
            local slot = SLOTS[i]
            local cur = getAttachedItem(animal, slot)
            if cur then
                local name = cur:getDisplayName() or slot
                uneqSub:addOption(T("Unequip") .. " " .. name,
                    player,
                    function(p, a, s)
                        queueHorseGearAction(p, a, function()
                            unequipAttachment(p, a, s)
                        end, 90, context)
                    end,
                    animal, slot
                )
            end
        end

        uneqSub:addOption(T("Unequip All"),
            player,
            function(p, a)
                queueHorseGearAction(p, a, function()
                    unequipAll(p, a)
                end, 150, context)
            end,
            animal
        )
    end
end

Events.OnClickedAnimalForContext.Add(addAttachmentOptions)

-----------------------------------------------------------------------
-- Re-apply attachments for on screen horses
-----------------------------------------------------------------------
local REAPPLY_RADIUS = 20
local reapplyTick = 0

local function reapplyFor(animal)
    if not HorseUtils.isHorse(animal) then return end
    local bySlot, ground = ensureHorseModData(animal)
    if not bySlot then return end

    local inv = animal:getInventory()

    for slot, fullType in pairs(bySlot) do
        if fullType and fullType ~= "" then
            local cur = getAttachedItem(animal, slot)
            if cur and cur:getFullType() == fullType then
                setAttachedItem(animal, slot, cur)
            else
                local found = inv and inv:FindAndReturn(fullType)
                if found then
                    setAttachedItem(animal, slot, found)
                    ground[slot] = nil
                else
                    local g = ground[slot]
                    if g and g.x and g.y and g.z then
                        local wo, sq = findWorldItemOnSquare(g.x, g.y, g.z, fullType, g.id)
                        if wo then
                            local picked = takeWorldItemToInventory(wo, sq, inv)
                            if picked then
                                setAttachedItem(animal, slot, picked)
                                ground[slot] = nil
                            end
                        end
                    end

                    if not getAttachedItem(animal, slot) then
                        if fullType ~= SADDLEBAG_CONTAINER_TYPE then
                            inv:AddItem(fullType)
                            local fetched = inv:FindAndReturn(fullType)
                            if fetched then setAttachedItem(animal, slot, fetched) end
                        end
                    end
                end
            end
            if slot == SADDLEBAG_SLOT then
                if fullType == SADDLEBAG_FULLTYPE then
                    ensureSaddlebagContainer(animal, nil)
                else
                    removeSaddlebagContainer(nil, animal)
                end
            end
        end
    end
    if not bySlot[SADDLEBAG_SLOT] then
        removeSaddlebagContainer(nil, animal)
    end
end

Events.OnTick.Add(function()
    reapplyTick = reapplyTick + 1
    if reapplyTick % 120 ~= 0 then return end

    local player = getPlayer()
    if not player then return end

    local cell = getCell()
    local z    = player:getZ()
    local px   = math.floor(player:getX())
    local py   = math.floor(player:getY())

    for x = px - REAPPLY_RADIUS, px + REAPPLY_RADIUS do
        for y = py - REAPPLY_RADIUS, py + REAPPLY_RADIUS do
            local sq = cell:getGridSquare(x, y, z)
            if sq then
                local animals = sq:getAnimals()
                if animals then
                    for i = 0, animals:size() - 1 do
                        local a = animals:get(i)
                        if a:isOnScreen() then
                            reapplyFor(a)
                        end
                    end
                end
            end
        end
    end
end)

-- local DROP_RADIUS = 50

-- local function dropContainerAttachmentsOnSave()
--     for p=0, getNumActivePlayers()-1 do
--         local player = getSpecificPlayer(p)
--         if player then
--             local z  = player:getZ()
--             local px = math.floor(player:getX())
--             local py = math.floor(player:getY())
--             local cell = getCell()

--             for x = px - DROP_RADIUS, px + DROP_RADIUS do
--                 for y = py - DROP_RADIUS, py + DROP_RADIUS do
--                     local sq = cell:getGridSquare(x, y, z)
--                     if sq then
--                         local animals = sq:getAnimals()
--                         if animals then
--                             for i=0, animals:size()-1 do
--                                 local a = animals:get(i)
--                                 if HorseUtils.isHorse(a) then
--                                     local bySlot, ground = ensureHorseModData(a)
--                                     for j = 1, #SLOTS do
--                                         local slot = SLOTS[j]
--                                         local cur = getAttachedItem(a, slot)
--                                         if cur and isContainerItem(cur) then
--                                             setAttachedItem(a, slot, nil)

--                                             local inv = a:getInventory()
--                                             if inv and inv:contains(cur) then inv:Remove(cur) end

--                                             sq:AddWorldInventoryItem(cur, 0.0, 0.0, 0.0)

--                                             local id = cur.getID and cur:getID() or nil
--                                             ground[slot] = { x = x + 0.0, y = y + 0.0, z = z, id = id }
--                                             bySlot[slot] = cur:getFullType()
--                                         end
--                                     end
--                                 end
--                             end
--                         end
--                     end
--                 end
--             end
--         end
--     end
-- end

-- Events.OnSave.Add(dropContainerAttachmentsOnSave)

