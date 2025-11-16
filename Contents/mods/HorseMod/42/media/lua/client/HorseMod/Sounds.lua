local HorseRiding = require("HorseMod/Riding")
local HorseUtils  = require("HorseMod/Utils")
local Stamina     = require("HorseMod/Stamina")

local HorseSounds = {}

local secAccum     = {}
local currentSound = {}
local currentSoundId   = {}
local lastEmitterByKey = {}
local tiredSoundId     = {}

local STRESS_MIN_INTERVAL = 15
local IDLE_MIN_INTERVAL   = 60
local STRESS_THRESHOLD    = 70

local stressAccum   = {}
local idleAccum     = {}

local speeds = {
    Walk   = 0.42,
    Trot   = 0.28,
    Gallop = 0.18,
}

local roughMaterials = { Sand=true, Grass=true, Gravel=true, Dirt=true }

local function horseKey(horse)
    if horse.getOnlineID then
        local id = horse:getOnlineID()
        if id and id ~= -1 then return "H"..tostring(id) end
    end
    return tostring(horse)
end

local function realTime()
    local gt = GameTime.getInstance()
    if gt and gt.getRealworldSecondsSinceLastUpdate then
        return gt:getRealworldSecondsSinceLastUpdate()
    end
end

local function getVolume()
    local options = PZAPI.ModOptions:getOptions("HorseMod")
    if not options then return 1.0 end
    local volume = options:getOption("HorseSoundVolume"):getValue()
    if volume then return volume end
    return 1.0
end

local function isSquareRough(square)
    if not square then return false end

    local floor = square:getFloor()
    if floor and floor.getProperties then
        local props = floor:getProperties()
        if props and props.Val then
            local mat = props:Val("FootstepMaterial")
            if mat and roughMaterials[mat] then return true end
        end
    end

    local objects = square:getObjects()
    if objects then
        for i = 0, objects:size()-1 do
            local obj = objects:get(i)
            if obj and obj.getProperties then
                local props = obj:getProperties()
                if props and props.Val then
                    local mat = props:Val("FootstepMaterial")
                    if mat and roughMaterials[mat] then return true end
                end
            end
        end
    end

    return false
end

local function playOneShot(emitter, name, vol)
    if not emitter or not name then return end
    local sid = emitter:playSound(name)
    if sid and emitter.setVolume then emitter:setVolume(sid, vol or 1.0) end
end

---Play the mount snort sound effect once.
---@param rider IsoPlayer | nil
---@param horse IsoAnimal | nil
function HorseSounds.playMountSnort(rider, horse)
    local emitter
    if horse and horse.getEmitter then
        emitter = horse:getEmitter()
    end

    if not emitter and rider and rider.getEmitter then
        emitter = rider:getEmitter()
    end

    playOneShot(emitter, "HorseMountSnort", getVolume())
end

local paramStateByKey = {}

local function checkParamAndTrigger(h, key, emitter, vol, varName, soundName, onTrigger)
    if not (h and emitter) then return end
    local now = h:getVariableBoolean(varName) or false
    local st  = paramStateByKey[key] or {}; paramStateByKey[key] = st
    local prev = st[varName] or false
    if now and not prev then
        playOneShot(emitter, soundName, vol)
        if onTrigger then onTrigger(h, key, emitter, vol) end
    end

    st[varName] = now
end

local function stopAllHorseSurfaces(emitter)
    if not emitter then return end
    emitter:stopSoundByName("HorseWalkConcrete")
    emitter:stopSoundByName("HorseTrotConcrete")
    emitter:stopSoundByName("HorseGallopConcrete")
    emitter:stopSoundByName("HorseWalkDirt")
    emitter:stopSoundByName("HorseTrotDirt")
    emitter:stopSoundByName("HorseGallopDirt")
    emitter:stopSoundByName("HorseGallopTired")
end

local function stopTiredLoopByKey(key, emitter)
    local wasPlaying = tiredSoundId[key]
    emitter = emitter or lastEmitterByKey[key]
    if emitter and (wasPlaying or emitter:isPlaying("HorseGallopTired")) then
        emitter:stopSoundByName("HorseGallopTired")
    end
    tiredSoundId[key] = nil
end

local function stopHorseLoopByKey(key, emitter)
    emitter = emitter or lastEmitterByKey[key]
    local name = currentSound[key]
    local sid  = currentSoundId[key]

    if emitter then
        if sid and emitter.stopSound then pcall(function() emitter:stopSound(sid) end) end
        if name then pcall(function() emitter:stopSoundByName(name) end) end
        stopAllHorseSurfaces(emitter)
        stopTiredLoopByKey(key, emitter)
    end

    currentSound[key]   = nil
    currentSoundId[key] = nil
    secAccum[key]       = 0
    stressAccum[key] = 0
    idleAccum[key]   = 0
    paramStateByKey[key] = nil
    tiredSoundId[key]   = nil
end

local function ensureEmitterBound(key, emitter)
    local last = lastEmitterByKey[key]
    if last and last ~= emitter then
        stopHorseLoopByKey(key, last)
    end
    lastEmitterByKey[key] = emitter
end

local _nearActive = {}
local _frameSeq   = 0

local function _dist2(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return dx*dx + dy*dy
end

local function shouldIdleSnort(h)
    local moving = h:isAnimalMoving()
    if moving then return false end
    if h:getVariableBoolean("MountingHorse") then return false end
    if h:getVariableBoolean("RidingHorse")   then return false end
    if h:getVariableBoolean("HorseEating")   then return false end
    if h:getVariableBoolean("HorseHurt")     then return false end
    return true
end

local function maybePlayStressed(h, key, emitter, dt, vol)
    local s = (h.getStress and h:getStress()) or 0
    stressAccum[key] = (s >= STRESS_THRESHOLD) and ((stressAccum[key] or 0) + dt) or 0
    if stressAccum[key] >= STRESS_MIN_INTERVAL then
        stressAccum[key] = 0
        playOneShot(emitter, "HorseStressed", vol)
    end
end

local function maybePlayIdleSnort(h, key, emitter, dt, vol)
    if shouldIdleSnort(h) then
        idleAccum[key] = (idleAccum[key] or 0) + dt
        if idleAccum[key] >= IDLE_MIN_INTERVAL then
            idleAccum[key] = 0
            playOneShot(emitter, "HorseIdleSnort", vol)
        end
    else
        idleAccum[key] = 0
    end
end

local function shouldPlayTiredGallop(horse)
    if not (horse and horse.getVariableBoolean and horse:getVariableBoolean("HorseGallop")) then
        return false
    end
    if not (Stamina and Stamina.get) then
        return false
    end
    local stamina = Stamina.get(horse)
    return stamina and stamina < 30
end

local function updateTiredGallopLoop(horse, key, emitter, vol)
    if not emitter then return end

    if shouldPlayTiredGallop(horse) then
        if not emitter:isPlaying("HorseGallopTired") then
            local sid = emitter:playSound("HorseGallopTired")
            if sid and emitter.setVolume then emitter:setVolume(sid, vol) end
            tiredSoundId[key] = sid or true
        end
    else
        stopTiredLoopByKey(key, emitter)
    end
end


function UpdateNearbyHorsesAudio()
    local player = getSpecificPlayer(0)
    if not player then return end

    _frameSeq = _frameSeq + 1
    local radius = 20
    local r2   = radius * radius
    local dt   = GameTime.getInstance():getTimeDelta()
    local rt   = realTime()
    local pid  = player:getPlayerNum()
    local vol  = getVolume()

    local myHorse = HorseRiding.getMountedHorse and HorseRiding.getMountedHorse(player)
    local myKey   = myHorse and horseKey(myHorse)

    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local cell = getCell()

    local seen      = {}
    local processed = {}
    local gx, gy    = math.floor(px), math.floor(py)

    local horses = {}
    for x = gx - radius, gx + radius do
        for y = gy - radius, gy + radius do
            local sq = cell:getGridSquare(x, y, pz)
            if sq then
                local animals = sq:getAnimals()
                if animals then
                    for i = 0, animals:size()-1 do
                        local h = animals:get(i)
                        if HorseUtils.isHorse(h) and h.isExistInTheWorld and h:isExistInTheWorld() then
                            local key = horseKey(h)
                            if key ~= myKey and not processed[key] then
                                local d2 = _dist2(px, py, h:getX(), h:getY())
                                if d2 <= r2 then
                                    processed[key] = true
                                    horses[#horses+1] = { h=h, key=key, d2=d2 }
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for i = 1, #horses do
        local h   = horses[i].h
        local key = horses[i].key

        seen[key] = true

        local emitter = (h.getEmitter and h:getEmitter())

        if not emitter then
            if currentSound[key] then
                stopHorseLoopByKey(key)
            end
        else
            ensureEmitterBound(key, emitter)
            checkParamAndTrigger(h, key, emitter, vol, "HorseDeath",  "HorseDeath", function()
                stopAllHorseSurfaces(emitter)
                currentSound[key]   = nil
                currentSoundId[key] = nil
            end)

            checkParamAndTrigger(h, key, emitter, vol, "HorseHurt",   "HorsePain")

            checkParamAndTrigger(h, key, emitter, vol, "HorseEating", "HorseEatingGrass")

            local moving  = h:isAnimalMoving() or h:getVariableBoolean("bMoving")
            local running = h.getVariableBoolean and h:getVariableBoolean("animalRunning")
            local base    = running and "HorseGallop" or "HorseWalk"
            local speed   = running and "Gallop" or "Walk"
            local rough   = isSquareRough(h:getSquare())
            local suffix  = rough and "Dirt" or "Concrete"
            local name    = base .. suffix

            if not moving then
                if currentSound[key] then
                    stopHorseLoopByKey(key, emitter)
                end
            else
                if currentSound[key] ~= name then
                    if currentSound[key] then
                        stopHorseLoopByKey(key, emitter)
                    end
                    local sid = emitter:playSound(name)
                    if sid and emitter.setVolume then emitter:setVolume(sid, vol) end
                    currentSound[key]   = name
                    currentSoundId[key] = sid
                    secAccum[key]       = 0
                else
                    if not emitter:isPlaying(name) then
                        local sid = emitter:playSound(name)
                        if sid and emitter.setVolume then emitter:setVolume(sid, vol) end
                        currentSoundId[key] = sid
                    end
                end

                local interval = (speed == "Gallop") and (speeds.Gallop or 0.18) or (speeds.Walk or 0.42)
                secAccum[key] = (secAccum[key] or 0) + dt
                if secAccum[key] >= interval then
                    secAccum[key] = secAccum[key] - interval
                    addSound(nil, h:getX(), h:getY(), h:getZ(), 4, 4)
                end
            end
            maybePlayStressed(h, key, emitter, rt, vol)
            maybePlayIdleSnort(h, key, emitter, rt, vol)
        end
    end

    local prev = _nearActive[pid]
    if prev then
        for key, _ in pairs(prev) do
            if not seen[key] and key ~= myKey then
                stopHorseLoopByKey(key)
            end
        end
    end
    _nearActive[pid] = seen
end

function UpdateHorseAudio(player, square)
    local horse = HorseRiding.getMountedHorse and HorseRiding.getMountedHorse(player)
    local emitter
    if horse and horse.isExistInTheWorld and horse:isExistInTheWorld() then
        emitter = (horse.getEmitter and horse:getEmitter()) or player:getEmitter()
    else
        stopAllHorseSurfaces(player and player:getEmitter())
        return
    end

    local vol = getVolume()

    local speed, base
    if horse:getVariableBoolean("HorseGallop") then
        speed, base = "Gallop", "HorseGallop"
    elseif horse:getVariableBoolean("HorseTrot") then
        speed, base = "Trot",   "HorseTrot"
    else
        speed, base = "Walk",   "HorseWalk"
    end

    local sq = square or horse:getSquare()
    local rough = isSquareRough(sq)
    local suffix = rough and "Dirt" or "Concrete"
    local soundName = base .. suffix

    local moving = horse:isAnimalMoving()
                or horse:getVariableBoolean("animalWalking")
                or horse:getVariableBoolean("HorseGallop")

    local key = horseKey(horse)
    local dt  = GameTime.getInstance():getTimeDelta()
    local rt  = realTime()

    checkParamAndTrigger(horse, key, emitter, vol, "HorseDeath",  "HorseDeath", function()
        stopAllHorseSurfaces(emitter)
        currentSound[key] = nil
        secAccum[key]     = 0
    end)
    checkParamAndTrigger(horse, key, emitter, vol, "HorseHurt",   "HorsePain")
    checkParamAndTrigger(horse, key, emitter, vol, "HorseEating", "HorseEatingGrass")

    maybePlayStressed(horse, key, emitter, rt, vol)
    maybePlayIdleSnort(horse, key, emitter, rt, vol)

    if not moving then
        stopAllHorseSurfaces(emitter)
        currentSound[key] = nil
        secAccum[key]     = 0
        stopTiredLoopByKey(key, emitter)
        return
    end

    updateTiredGallopLoop(horse, key, emitter, vol)

    if currentSound[key] ~= soundName then
        if currentSound[key] and emitter then
            emitter:stopSoundByName(currentSound[key])
        end
        if emitter and not emitter:isPlaying(soundName) then
            local sid = emitter:playSound(soundName)
            if sid and emitter.setVolume then emitter:setVolume(sid, vol) end
        end
        currentSound[key] = soundName
        secAccum[key]     = 0
    else
        if emitter and not emitter:isPlaying(soundName) then
            local sid = emitter:playSound(soundName)
            if sid and emitter.setVolume then emitter:setVolume(sid, vol) end
        end
    end

    local interval = speeds[speed] or 0.3
    secAccum[key] = (secAccum[key] or 0) + dt
    if secAccum[key] >= interval then
        secAccum[key] = secAccum[key] - interval
        addSound(nil, horse:getX(), horse:getY(), horse:getZ(), 4, 4)
    end
end

Events.OnPlayerUpdate.Add(UpdateNearbyHorsesAudio)

return HorseSounds

