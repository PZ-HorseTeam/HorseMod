---@namespace HorseMod

local HorseManager = require("HorseMod/HorseManager")
local AnimationVariable = require('HorseMod/definitions/AnimationVariable')
local Stamina = require("HorseMod/Stamina")
local Mounts = require("HorseMod/Mounts")
local HorseSoundVolume = require("HorseMod/sound/HorseSoundVolume")
local HorseSoundFootsteps = require("HorseMod/sound/HorseSoundFootsteps")


---@enum Sound
local Sound = {
    IDLE = "HorseIdleSnort",
    STRESSED = "HorseStressed",
    EATING = "HorseEating",
    PAIN = "HorsePain",
    GALLOP_ROUGH = HorseSoundFootsteps.Sound.GALLOP_ROUGH,
    GALLOP_SMOOTH = HorseSoundFootsteps.Sound.GALLOP_SMOOTH,
    TROT_ROUGH = HorseSoundFootsteps.Sound.TROT_ROUGH,
    TROT_SMOOTH = HorseSoundFootsteps.Sound.TROT_SMOOTH,
    WALK_ROUGH = HorseSoundFootsteps.Sound.WALK_ROUGH,
    WALK_SMOOTH = HorseSoundFootsteps.Sound.WALK_SMOOTH,
    TIRED = HorseSoundFootsteps.Sound.TIRED,
    MOUNT = "HorseMountSnort",
    DEATH = "HorseDeath"
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
---@readonly
local FOOTSTEP_SWITCH_DEBOUNCE_SECONDS = 0.10
---@readonly So client game freezes doesn't stack a bunch of footstep sounds
local FOOTSTEP_RESTART_COOLDOWN_SECONDS = 0.20
---@readonly Get rid of sound jitter that can happen when horse is switching between different
-- movement states
local SPEED_SAMPLE_WINDOW_SECONDS = 0.25
---@readonly
local MAX_TICK_DELTA = 0.10


---the only path that should call playSoundImpl in this file, every other start
---must go through here so the isPlaying guard cannot be skipped
---@param emitter BaseCharacterSoundEmitter
---@param soundName string
---@param volume number
---@return integer handle
local function playSoundOnce(emitter, soundName, volume)
    if emitter:isPlaying(soundName) then
        emitter:stopSoundByName(soundName)
    end
    local handle = emitter:playSoundImpl(soundName, nil--[[@as IsoObject]])
    emitter:setVolume(handle, volume)
    return handle
end


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
---Sound the gait wants this tick, before the switch-debounce passes.
---@field footstepCandidate Sound?
---
---Cumulative seconds the current candidate has been requested.
---@field footstepCandidateAge number
---
---Seconds remaining before a new footstep `playSound` may be issued.
---@field footstepStartCooldown number
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
---
---Position of the older speed-window sample (world coordinates)
---@field speedSampleX number
---@field speedSampleY number
---
---Seconds since the older speed-window sample.
---@field speedSampleAge number
---
---Last-computed smoothed speed, tiles/sec.
---@field smoothedSpeedPerSec number
local HorseSounds = {}
HorseSounds.__index = HorseSounds


---@class SoundsSystem : System
local SoundsSystem = {}


---@param emitter BaseCharacterSoundEmitter
---@param sound Sound
---@return integer handle Handle of the played sound.
function SoundsSystem:playOneShot(emitter, sound)
    return playSoundOnce(emitter, sound, self.volume)
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
        -- Without resetting, this branch fires every tick after the first 4s and floods WorldSoundPacket
        self.attractionEventTimer = self.attractionEventTimer % ATTRACTION_EVENT_INTERVAL_SECONDS
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


-- Unmounted horses runs slower than the mounted horses, so need separate speeds
-- used to trigger walk and gallop sounds
---@readonly
local MOUNTED_SPEED_GALLOP = 5.5
---@readonly
local MOUNTED_SPEED_TROT = 2.5
---@readonly
local MOUNTED_SPEED_WALK = 0.5

---@readonly
local WILD_SPEED_GALLOP = 2.5
---@readonly
local WILD_SPEED_TROT = 1.2
---@readonly
local WILD_SPEED_WALK = 0.3


---@param subject IsoGameCharacter
---@param delta number seconds since last call
---@param isWild boolean
function HorseSounds:refreshSmoothedSpeed(subject, delta, isWild)
    self.speedSampleAge = self.speedSampleAge + delta
    if self.speedSampleAge < SPEED_SAMPLE_WINDOW_SECONDS then
        return
    end

    local x = subject:getX()
    local y = subject:getY()
    local dx = x - self.speedSampleX
    local dy = y - self.speedSampleY
    local distance = math.sqrt(dx * dx + dy * dy)
    self.smoothedSpeedPerSec = distance / self.speedSampleAge

    self.speedSampleX = x
    self.speedSampleY = y
    self.speedSampleAge = 0
end


---Derive footstep gait
---@param delta number Game-seconds since last update.
---@return MovementState
function HorseSounds:getMovementState(delta)
    local localPlayer = getPlayer()
    local isLocalMount = localPlayer and Mounts.getMount(localPlayer) == self.animal

    local gallopBand, trotBand, walkBand
    if isLocalMount then
        self:refreshSmoothedSpeed(localPlayer, delta, false)
        gallopBand = MOUNTED_SPEED_GALLOP
        trotBand = MOUNTED_SPEED_TROT
        walkBand = MOUNTED_SPEED_WALK
    else
        self:refreshSmoothedSpeed(self.animal, delta, true)
        gallopBand = WILD_SPEED_GALLOP
        trotBand = WILD_SPEED_TROT
        walkBand = WILD_SPEED_WALK
    end

    local speed = self.smoothedSpeedPerSec

    -- Stop footsteps sounds during jump
    if self.animal:getVariableBoolean(AnimationVariable.JUMP) then
        return "idle"
    end

    -- Without this the trot toggle while standing still
    -- plays the footstep loop
    if speed < walkBand then
        return "idle"
    end

    if self.animal:getVariableBoolean(AnimationVariable.GALLOP) then
        return "gallop"
    end
    if self.animal:getVariableBoolean(AnimationVariable.TROT) then
        return "trot"
    end

    if speed >= gallopBand then
        return "gallop"
    end
    if speed >= trotBand then
        return "trot"
    end
    return "walking"
end


function HorseSounds:stopFootsteps()
    local emitter = self.lastEmitter or self.animal:getEmitter()
    if self.footstepSound then
        emitter:stopSoundByName(self.footstepSound)
    end
    self.footstepHandle = -1
end


---@param delta number
function HorseSounds:updateFootsteps(delta)
    local movementState = self:getMovementState(delta)
    local sound = HorseSoundFootsteps.getSoundForGait(movementState, self.animal:getSquare())

    if sound ~= self.footstepCandidate then
        self.footstepCandidate = sound
        self.footstepCandidateAge = 0
    else
        self.footstepCandidateAge = self.footstepCandidateAge + delta
    end

    self.footstepStartCooldown = math.max(0, self.footstepStartCooldown - delta)

    local emitter = self.animal:getEmitter()

    if sound ~= self.footstepSound
            and self.footstepCandidateAge >= FOOTSTEP_SWITCH_DEBOUNCE_SECONDS
            and self.footstepStartCooldown <= 0 then

        if self.footstepHandle ~= -1 then
            self:stopFootsteps()
        end

        if sound then
            self.footstepHandle = playSoundOnce(emitter, sound, SoundsSystem.volume)
            self.lastEmitter = emitter
            self.footstepStartCooldown = FOOTSTEP_RESTART_COOLDOWN_SECONDS
        end

        self.footstepSound = sound
    end

    if self.footstepHandle ~= -1 then
        if self.footstepSound and not emitter:isPlaying(self.footstepSound) then
            self.footstepHandle = -1
        else
            emitter:setVolume(self.footstepHandle, SoundsSystem.volume)
        end
    end
end


function HorseSounds:stopTiredSound()
    if self.tiredSoundHandle == -1 then
        return
    end
    self.animal:getEmitter():stopSoundByName(Sound.TIRED)
    self.tiredSoundHandle = -1
end


function HorseSounds:updateTiredSound()
    local emitter = self.animal:getEmitter()
    if self:getMovementState(0) == "gallop" and Stamina.get(self.animal) <= MAX_STAMINA_FOR_TIRED_SOUND then
        if self.tiredSoundHandle == -1 or not emitter:isPlaying(Sound.TIRED) then
            self.tiredSoundHandle = playSoundOnce(emitter, Sound.TIRED, SoundsSystem.volume)
        else
            emitter:setVolume(self.tiredSoundHandle, SoundsSystem.volume)
        end
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


---When the animal is ridden by a remote player, RemoteHorseSounds.lua's 250 ms
---poll owns the footstep and tired sounds. Running the OnTick path here too would
---play duplicates, so skip the loop sounds in that case
---@return boolean
---@nodiscard
function HorseSounds:isOwnedByRemoteRider()
    local rider = Mounts.getRider(self.animal)
    if not rider then
        return false
    end
    return rider ~= getPlayer()
end


---@param delta number Game-seconds since last update.
function HorseSounds:update(delta)
    self:updateVariableWatches()
    if self:isOwnedByRemoteRider() then
        -- Make sure no lingering footsteps/tired loop from a previous rider is
        -- still running on the emitter
        if self.footstepHandle ~= -1 or self.footstepSound then
            self:stopFootsteps()
            self.footstepSound = nil
            self.footstepCandidate = nil
            self.footstepCandidateAge = 0
        end
        if self.tiredSoundHandle ~= -1 then
            self:stopTiredSound()
        end
    else
        self:updateFootsteps(delta)
        self:updateTiredSound()
    end
    self:updateStressedSounds(delta)
    self:updateIdleSounds(delta)
    self:updateAttraction(delta)
end


function SoundsSystem:update(horses, delta)
    -- clamp for catch-up frames if there's a freeze so it doesn't play
    -- many sounds at once
    if delta > MAX_TICK_DELTA then
        delta = MAX_TICK_DELTA
    end

    self.volume = HorseSoundVolume.getLive()

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
            footstepCandidate = nil,
            footstepCandidateAge = 0,
            footstepStartCooldown = 0,
            lastEmitter = nil,
            tiredSoundHandle = -1,
            variableCache = {},
            variableWatches = {},
            stressDebounce = 0,
            idleDebounce = 0,
            attractionEventTimer = 0,
            speedSampleX = animal:getX(),
            speedSampleY = animal:getY(),
            speedSampleAge = 0,
            smoothedSpeedPerSec = 0,
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
    HorseSoundFootsteps.stopAllOn(animal:getEmitter())

    SoundsSystem.horseSounds[animal] = nil
end

HorseManager.onHorseRemoved:add(removeHorseSounds)


---Stop the footstep loop when the rider dismounts
---@param player IsoPlayer
---@param dismountedAnimal IsoAnimal
Mounts.onDismount:add(function(player, dismountedAnimal)
    local horseSounds = SoundsSystem.horseSounds[dismountedAnimal]
    if horseSounds then
        horseSounds:stopFootsteps()
    end
end)


local HorseSoundsExport = {}

HorseSoundsExport.Sound = Sound


---@param animal IsoAnimal
---@param sound Sound
function HorseSoundsExport.playSound(animal, sound)
    SoundsSystem:playOneShot(animal:getEmitter(), sound)
end


return HorseSoundsExport
