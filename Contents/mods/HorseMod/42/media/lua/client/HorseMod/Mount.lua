---@namespace HorseMod


---@class Mount
---
---@field pair MountPair
local Mount = {}
Mount.__index = Mount


function Mount:update()
    -- TODO: TEMP, RideDirect should be cleaned up and merged into here over time

    -- delaying the require until here prevents a circular dependency
    --  it's bad for performance but this is not permanent
    require("HorseMod/RideDirect").update(self.pair.rider)
end


function Mount:cleanup()
    self.pair:setAnimationVariable("RidingHorse", false)
    self.pair:setAnimationVariable("HorseTrot", false)

    local attached = self.pair.rider:getAttachedAnimals()
    attached:remove(self.pair.mount)
    self.pair.mount:getData():setAttachedPlayer(nil)

    self.pair.mount:getBehavior():setBlockMovement(false)
    self.pair.mount:getPathFindBehavior2():reset()

    self.pair.rider:setVariable("HorseTrot", false)
    self.pair.rider:setAllowRun(true)
    self.pair.rider:setAllowSprint(true)
    self.pair.rider:setTurnDelta(1)
    self.pair.rider:setSneaking(false)

    self.pair.mount:setVariable("bPathfind", false)
    self.pair.mount:setVariable("animalWalking", false)
    self.pair.mount:setVariable("animalRunning", false)

    self.pair.rider:setVariable("MountingHorse", false)
    self.pair.rider:setVariable("isTurningLeft", false)
    self.pair.rider:setVariable("isTurningRight", false)
end


---@param pair MountPair
---@return Mount
---@nodiscard
function Mount.new(pair)
    pair.rider:getAttachedAnimals():add(pair.mount)
    pair.mount:getData():setAttachedPlayer(pair.rider)

    pair:setAnimationVariable("RidingHorse", true)
    pair:setAnimationVariable("HorseTrot", false)
    pair.rider:setAllowRun(false)
    pair.rider:setAllowSprint(false)

    pair.rider:setTurnDelta(0.65)

    pair.rider:setVariable("isTurningLeft", false)
    pair.rider:setVariable("isTurningRight", false)

    local geneSpeed = pair.mount:getUsedGene("speed"):getCurrentValue()
    pair.rider:setVariable("geneSpeed", geneSpeed)

    pair.mount:getPathFindBehavior2():reset()
    pair.mount:getBehavior():setBlockMovement(true)
    pair.mount:stopAllMovementNow()

    pair.mount:setVariable("bPathfind", false)
    pair.mount:setVariable("animalWalking", false)
    pair.mount:setVariable("animalRunning", false)

    -- TODO: are these even needed
    pair.mount:setWild(false)
    pair.mount:setVariable("isHorse", true)

    return setmetatable(
        {
            pair = pair
        },
        Mount
    )
end


return Mount