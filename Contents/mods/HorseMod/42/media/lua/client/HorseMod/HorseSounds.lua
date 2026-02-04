---@namespace HorseMod

local HorseManager = require("HorseMod/HorseManager")
local AnimationVariable = require('HorseMod/definitions/AnimationVariable')
local Stamina = require("HorseMod/Stamina")
local ModOptions = require("HorseMod/ModOptions")


---@enum Sound
local Sound = {
    IDLE = "HorseIdleSnort",
    STRESSED = "HorseStressed",
    EATING = "HorseEating",
    PAIN = "HorsePain",
    GALLOP_ROUGH = "HorseGallopDirt",
    GALLOP_SMOOTH = "HorseGallopConcrete",
    TROT_ROUGH = "HorseTrotDirt",
    TROT_SMOOTH = "HorseTrotConcrete",
    WALK_ROUGH = "HorseWalkDirt",
    WALK_SMOOTH = "HorseWalkConcrete",
    TIRED = "HorseGallopTired",
    MOUNT = "HorseMountSnort",
    DEATH = "HorseDeath"
}

---@class FootstepSounds
---@field rough Sound?
---@field smooth Sound?

---@type table<MovementState, FootstepSounds>
local footsteps = {
    gallop = {
        rough = Sound.GALLOP_ROUGH,
        smooth = Sound.GALLOP_SMOOTH
    },
    trot = {
        rough = Sound.TROT_ROUGH,
        smooth = Sound.TROT_SMOOTH
    },
    walking = {
        rough = Sound.WALK_ROUGH,
        smooth = Sound.WALK_SMOOTH
    },
    idle = {
        rough = nil,
        smooth = nil
    }
}

---@readonly
local MIN_STRESS_FOR_SOUND = 85
---@readonly
local STRESS_INTERVAL_SECONDS = 180
---@readonly
local IDLE_INTERVAL_SECONDS = 60
---@readonly
local ATTRACTION_EVENT_INTERVAL_SECONDS = 4
---@readonly
local MAX_STAMINA_FOR_TIRED_SOUND = 30


---Plays a sound when a variable first becomes true.
---@class HorseSounds.VariableWatch
---
---Animation variable to check.
---@field variable AnimationVariable
---
---Sound to play when the variable becomes true.
---@field sound Sound
---
---Cached last seen value of the animation variable.
---@field lastValue boolean


---@class HorseSounds
---
---Associated animal.
---@field animal IsoAnimal
---
---Currently playing footstep sound. Nil if not playing a sound.
---@field footstepSound Sound?
---
---Handle of the currently playing footstep sound. `-1` if none is playing.
---@field footstepHandle integer
---
---Last emitter used to play a sound.
---@field lastEmitter BaseCharacterSoundEmitter?
---
---Handle to the galloping tired sound. `-1` if it is not playing.
---@field tiredSoundHandle integer
---
---Sounds to play when a variable changes.
---@field variableWatches HorseSounds.VariableWatch[]
---
---Seconds since last stressed sound to avoid spam.
---@field stressDebounce number
---
---Seconds since last idle sound to avoid spam.
---@field idleDebounce number
---
---Seconds since last attraction event.
---@field attractionEventTimer number
local HorseSounds = {}
HorseSounds.__index = HorseSounds


---@class SoundsSystem : System
local SoundsSystem = {}


---@param emitter BaseCharacterSoundEmitter
---@param sound Sound
---@return integer handle Handle of the played sound.
function SoundsSystem:playOneShot(emitter, sound)
    local handle = emitter:playSound(sound)
    emitter:setVolume(handle, self.volume)

    return handle
end



---@type table<IsoAnimal, HorseSounds?>
SoundsSystem.horseSounds = {}


---@type number
SoundsSystem.volume = 1


---@param variable AnimationVariable
---@param sound Sound
function HorseSounds:addVariableWatch(variable, sound)
    self.variableWatches[#self.variableWatches + 1] = {
        variable = variable,
        sound = sound,
        lastValue = false
    }
end


---@param delta number
function HorseSounds:updateAttraction(delta)
    self.attractionEventTimer = self.attractionEventTimer + delta
    if self.attractionEventTimer >= ATTRACTION_EVENT_INTERVAL_SECONDS then
        -- TODO: radius and volume should depend on current movement
        addSound(
            self.animal,
            math.floor(self.animal:getX()),
            math.floor(self.animal:getY()),
            math.floor(self.animal:getZ()),
            4,
            4
        )
    end
end


---@param animal IsoAnimal
---@return boolean
---@nodiscard
local function shouldIdleSnort(animal)
    if animal:getMovementSpeed() >= 0.01 then
        return false
    end
    if animal:getVariableBoolean(AnimationVariable.MOUNTING_HORSE) then
        return false
    end
    if animal:getVariableBoolean(AnimationVariable.RIDING_HORSE) then
        return false
    end
    if animal:getVariableBoolean(AnimationVariable.EATING) then
        return false
    end
    if animal:getVariableBoolean(AnimationVariable.HURT) then
        return false
    end

    return true
end


---@param delta number
function HorseSounds:updateIdleSounds(delta)
    if not shouldIdleSnort(self.animal) then
        return
    end

    self.idleDebounce = self.idleDebounce + delta
    if self.idleDebounce >= IDLE_INTERVAL_SECONDS then
        self.idleDebounce = self.idleDebounce % IDLE_INTERVAL_SECONDS
        SoundsSystem:playOneShot(self.animal:getEmitter(), Sound.IDLE)
    end
end


---@param delta number
function HorseSounds:updateStressedSounds(delta)
    local stress = self.animal:getStress()
    if stress >= MIN_STRESS_FOR_SOUND then
        self.stressDebounce = self.stressDebounce + delta
        if self.stressDebounce >= STRESS_INTERVAL_SECONDS then
            self.stressDebounce = self.stressDebounce % STRESS_INTERVAL_SECONDS
            SoundsSystem:playOneShot(
                self.animal:getEmitter(),
                Sound.STRESSED
            )
        end
    else
        self.stressDebounce = 0
    end
end


---@param animal IsoAnimal
---@return MovementState
---@nodiscard
local function getMovementState(animal)
    -- FIXME: this is basically a duplicate of MountController:getMovementState because we don't always have a Mount to check
    if animal:getMovementSpeed() < 0.01 then
        return "idle"
    elseif animal:getVariableBoolean(AnimationVariable.GALLOP) then
        return "gallop"
    elseif animal:getVariableBoolean(AnimationVariable.TROT) then
        return "trot"
    else
        return "walking"
    end
end


---@type table<string, true?>
local ROUGH_MATERIALS = { Sand = true, Grass = true, Gravel = true, Dirt = true }


---@param square IsoGridSquare
---@return boolean
---@nodiscard
local function isSquareRough(square)
    local floor = square:getFloor()
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


function HorseSounds:stopFootsteps()
    self.animal:getEmitter():stopSound(self.footstepHandle)
    self.footstepHandle = -1
end


function HorseSounds:updateFootsteps()
    local movementState = getMovementState(self.animal)
    local sound
    if isSquareRough(self.animal:getSquare()) then
        sound = footsteps[movementState].rough
    else
        sound = footsteps[movementState].smooth
    end

    local emitter = self.animal:getEmitter()

    if sound ~= self.footstepSound then
        if self.footstepHandle ~= -1 then
            self:stopFootsteps()
        end

        if sound then
            self.footstepHandle = emitter:playSound(sound)
        end

        self.footstepSound = sound
    end

    if self.footstepHandle ~= 1 then
        emitter:setVolume(self.footstepHandle, SoundsSystem.volume)
    end
end


function HorseSounds:stopTiredSound()
    self.animal:getEmitter():stopSound(self.tiredSoundHandle)
end


function HorseSounds:updateTiredSound()
    local emitter = self.animal:getEmitter()
    if getMovementState(self.animal) == "gallop" and Stamina.get(self.animal) <= MAX_STAMINA_FOR_TIRED_SOUND then
        if self.tiredSoundHandle == -1 then
            self.tiredSoundHandle = emitter:playSound(Sound.TIRED)
        end
        emitter:setVolume(self.tiredSoundHandle, SoundsSystem.volume)
    elseif self.tiredSoundHandle ~= -1 then
        self:stopTiredSound()
    end
end


function HorseSounds:updateVariableWatches()
    local emitter = self.animal:getEmitter()
    for i = 1, #self.variableWatches do
        local variableWatch = self.variableWatches[i]
        local previousValue = variableWatch.lastValue
        local value = self.animal:getVariableBoolean(variableWatch.variable)
        variableWatch.lastValue = value

        if value and value ~= previousValue then
            SoundsSystem:playOneShot(emitter, variableWatch.sound)
        end
    end
end


---@param delta number
function HorseSounds:update(delta)
    self:updateVariableWatches()
    self:updateFootsteps()
    self:updateTiredSound()
    self:updateStressedSounds(delta)
    self:updateIdleSounds(delta)            
    self:updateAttraction(delta)
end


function SoundsSystem:update(horses, delta)
    -- need to update this each tick incase the player changes their volume
    self.volume = getCore():getOptionSoundVolume() * 0.1 * ModOptions.HorseSoundVolume

    for i = 1, #horses do
        local horse = horses[i]

        local horseSounds = SoundsSystem.horseSounds[horse]
        assert(horseSounds ~= nil, "SoundsSystem.update encountered a horse with no HorseSounds")

        horseSounds:update(delta)
    end
end


table.insert(HorseManager.systems, SoundsSystem)


---@param animal IsoAnimal
local function createHorseSounds(animal)
    local horseSounds = setmetatable(
        {
            animal = animal,
            footstepSound = nil,
            footstepHandle = -1,
            lastEmitter = nil,
            tiredSoundHandle = -1,
            variableCache = {},
            variableWatches = {},
            stressDebounce = 0,
            idleDebounce = 0,
            attractionEventTimer = 0
        },
        HorseSounds
    )

    horseSounds:addVariableWatch(AnimationVariable.HURT, Sound.PAIN)
    horseSounds:addVariableWatch(AnimationVariable.EATING, Sound.EATING)

    SoundsSystem.horseSounds[animal] = horseSounds
end

HorseManager.onHorseAdded:add(createHorseSounds)


---@param animal IsoAnimal
local function removeHorseSounds(animal)
    local horseSounds = SoundsSystem.horseSounds[animal]
    if not horseSounds then
        return
    end

    horseSounds:stopFootsteps()
    horseSounds:stopTiredSound()

    SoundsSystem.horseSounds[animal] = nil
end

HorseManager.onHorseRemoved:add(removeHorseSounds)


local HorseSounds = {}

HorseSounds.Sound = Sound


---@param animal IsoAnimal
---@param sound Sound
function HorseSounds.playSound(animal, sound)
    SoundsSystem:playOneShot(animal:getEmitter(), sound)
end


return HorseSounds
