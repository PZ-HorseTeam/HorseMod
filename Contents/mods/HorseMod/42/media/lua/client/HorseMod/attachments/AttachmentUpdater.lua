---@namespace HorseMod

---REQUIREMENTS
local Attachments = require("HorseMod/attachments/Attachments")
local AttachmentVisuals = require("HorseMod/attachments/AttachmentVisuals")
local HorseManager = require("HorseMod/HorseManager")
local ManeManager = require("HorseMod/attachments/ManeManager")
local HorseModData = require("HorseMod/HorseModData")

---@class AttachmentUpdater : System
local AttachmentUpdater = {
    -- DEBUG_AttachmentUpdater = true,

    ---Holds currently already reapplied horses.
    ---@type table<IsoAnimal, true?>
    IS_REAPPLIED = {},
}
local IS_REAPPLIED = AttachmentUpdater.IS_REAPPLIED

---Reapply attachments to the `horse`.
---@param horse IsoAnimal
AttachmentUpdater.reapplyFor = function(horse)
    local inv = horse:getInventory()
    local bySlot = HorseModData.get(horse, Attachments.ATTACHMENTS_MOD_DATA).bySlot

    for slot, fullType in pairs(bySlot) do
        -- try to retrieve the item from attached items, else create a fresh one
        local item = AttachmentVisuals.get(horse, slot)
        if not item then
            item = inv:AddItem(fullType)
        end

        -- safeguard for removed/invalid slots
        if not Attachments.isSlot(slot) then
            return
        end

        -- setup mane color
        if ManeManager.isManeSlot(slot) then
            ManeManager.setupMane(horse, item, slot)
        end

        AttachmentVisuals.set(horse, slot, item)
    end

    -- set horse as reapplied
    IS_REAPPLIED[horse] = true
end


AttachmentUpdater.updateLights = function(horse)
    local lights = AttachmentVisuals.lights[horse]
    if not lights then return end

    local x, y, z = horse:getX(), horse:getY(), horse:getZ()
    for _, lightData in pairs(lights) do
        ---@cast lightData {behavior: LightBehavior, source: IsoLightSource?} -- fucked up EmmyLua

        -- remove previous source
        local source = lightData.source
        if source then
            getCell():removeLamppost(source)
        end

        -- create the light source and place it in the world
        local behavior = lightData.behavior
        local rgb = behavior.rgb
        local radius = behavior.radius
        local light = IsoLightSource.new(x, y, z, rgb.r, rgb.g, rgb.b, radius)
        getCell():addLamppost(light)
        lightData.source = light
    end
end

---Verify that the horse doesn't need to get its attachments reapplied, and if yes
---then reapply those and set the horse status for updates.
---@param horses IsoAnimal[]
---@param delta number
function AttachmentUpdater:update(horses, delta)
    for i = 1, #horses do
        local horse = horses[i]

        AttachmentUpdater.updateLights(horse)

        -- if horse model is visible, set it as needing an update if not already reapplied
        local status = IS_REAPPLIED[horse]
        if horse:getModel() then
            if not status then
                AttachmentUpdater.reapplyFor(horse)
            end

        -- else set horse as needing to be reapplied until it's visible again
        else
            if status then
                IS_REAPPLIED[horse] = nil
            end
        end
    end
end


---@TODO remove/comment for proper release, this is used to hot reload in-game for testing
-- for i, system in ipairs(HorseManager.systems) do
--     ---@diagnostic disable-next-line
--     if system.DEBUG_AttachmentUpdater then
--         table.remove(HorseManager.systems,i)
--     end
-- end

table.insert(HorseManager.systems, AttachmentUpdater)


return AttachmentUpdater