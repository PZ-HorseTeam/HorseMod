---@namespace HorseMod

---@alias MovementState "idle"|"walking"|"trot"|"gallop"

local HorseSoundFootsteps = {}


---@enum HorseSoundFootsteps.Sound
HorseSoundFootsteps.Sound = {
    GALLOP_ROUGH = "HorseGallopDirt",
    GALLOP_SMOOTH = "HorseGallopConcrete",
    TROT_ROUGH = "HorseTrotDirt",
    TROT_SMOOTH = "HorseTrotConcrete",
    WALK_ROUGH = "HorseWalkDirt",
    WALK_SMOOTH = "HorseWalkConcrete",
    TIRED = "HorseGallopTired"
}


---@class HorseSoundFootsteps.GaitEntry
---@field rough HorseSoundFootsteps.Sound?
---@field smooth HorseSoundFootsteps.Sound?

---@type table<MovementState, HorseSoundFootsteps.GaitEntry>
HorseSoundFootsteps.byGait = {
    gallop = {
        rough = HorseSoundFootsteps.Sound.GALLOP_ROUGH,
        smooth = HorseSoundFootsteps.Sound.GALLOP_SMOOTH
    },
    trot = {
        rough = HorseSoundFootsteps.Sound.TROT_ROUGH,
        smooth = HorseSoundFootsteps.Sound.TROT_SMOOTH
    },
    walking = {
        rough = HorseSoundFootsteps.Sound.WALK_ROUGH,
        smooth = HorseSoundFootsteps.Sound.WALK_SMOOTH
    },
    idle = {
        rough = nil,
        smooth = nil
    }
}


---All footstep sound names, for cleanup
---@type string[]
HorseSoundFootsteps.allFootstepNames = {
    HorseSoundFootsteps.Sound.GALLOP_ROUGH,
    HorseSoundFootsteps.Sound.GALLOP_SMOOTH,
    HorseSoundFootsteps.Sound.TROT_ROUGH,
    HorseSoundFootsteps.Sound.TROT_SMOOTH,
    HorseSoundFootsteps.Sound.WALK_ROUGH,
    HorseSoundFootsteps.Sound.WALK_SMOOTH,
    HorseSoundFootsteps.Sound.TIRED
}


---@type table<string, true?>
local ROUGH_MATERIALS = { Sand = true, Grass = true, Gravel = true, Dirt = true }


---@param square IsoGridSquare?
---@return boolean
---@nodiscard
function HorseSoundFootsteps.isSquareRough(square)
    if not square then
        return false
    end

    local floor = square:getFloor() ---@as IsoObject?
    if floor then
        local material = floor:getProperty("FootstepMaterial")
        if ROUGH_MATERIALS[material] then
            return true
        end
    end

    ---@type IsoObject[]
    local objects = square:getLuaTileObjectList()
    for i = 1, #objects do
        local object = objects[i]
        local material = object:getProperty("FootstepMaterial")
        if ROUGH_MATERIALS[material] then
            return true
        end
    end

    return false
end


---@param gait MovementState
---@param square IsoGridSquare?
---@return HorseSoundFootsteps.Sound?
---@nodiscard
function HorseSoundFootsteps.getSoundForGait(gait, square)
    local entry = HorseSoundFootsteps.byGait[gait]
    if not entry then
        return nil
    end

    if HorseSoundFootsteps.isSquareRough(square) then
        return entry.rough
    end

    return entry.smooth
end


---Cleanup cached footstep sounds on an emitter
---@param emitter BaseCharacterSoundEmitter
function HorseSoundFootsteps.stopAllOn(emitter)
    if not emitter then
        return
    end

    for i = 1, #HorseSoundFootsteps.allFootstepNames do
        emitter:stopSoundByName(HorseSoundFootsteps.allFootstepNames[i])
    end
end


return HorseSoundFootsteps
