---@namespace HorseMod

local HorseDamage = require("HorseMod/horse/HorseDamage")
local AnimationVariable = require('HorseMod/definitions/AnimationVariable')
local Attachments = require("HorseMod/attachments/Attachments")
local Mounts = require("HorseMod/Mounts")

local PlayerDamage = {}

---@alias DamageType
---| "scratch"
---| "bite"

-- maximum pain from riding allowed on each affected body part
PlayerDamage.MAX_PAIN_BAREBACK = 20
PlayerDamage.MAX_PAIN_SADDLE = 10
-- pain per second while riding without a saddle
PlayerDamage.PAIN_RATE_BAREBACK = 0.36
-- pain per second while riding with a saddle
PlayerDamage.PAIN_RATE_SADDLE = 0.12


-- Scratch damage range
PlayerDamage.DMG_SCR_MIN = 0.15
PlayerDamage.DMG_SCR_MAX = 0.6
-- Laceration damage range
PlayerDamage.DMG_LAC_MIN = 0.5
PlayerDamage.DMG_LAC_MAX = 1.3
-- Bite damage range
PlayerDamage.DMG_BIT_MIN = 1.8
PlayerDamage.DMG_BIT_MAX = 3.2


---@return ArrayList<IsoPlayer>
---@nodiscard
local function getPlayers()
    if isServer() then
        return getOnlinePlayers()
    end

    local players = IsoPlayer.getPlayers()

    -- stupid arraylist has null in it
    while players:contains(nil) do
        players:remove(nil)
    end

    -- does remove(index) not work because of kahlua's overload resolver??
    -- for i = players:size() - 1, 0, -1 do
    --     if players:get(i) == nil then
    --         players:remove(i)
    --     end
    -- end

    return players
end


---@param player IsoPlayer
function PlayerDamage.applyRidingPain(player)
    local horse = Mounts.getMount(player)
    if not horse then
        return
    end

    if not player:getVariableBoolean("pressedmovement") then
        return
    end

    local hasSaddle = Attachments.getSaddle(horse) ~= nil

    local rate = hasSaddle and PlayerDamage.PAIN_RATE_SADDLE or PlayerDamage.PAIN_RATE_BAREBACK
    local maxPain = hasSaddle and PlayerDamage.MAX_PAIN_SADDLE or PlayerDamage.MAX_PAIN_BAREBACK
    local bodyDamage = player:getBodyDamage()

    rate = rate * getGameTime():getTimeDelta()

    ---@type BodyPartType[]
    local bodyPartsList = { BodyPartType.UpperLeg_L, BodyPartType.UpperLeg_R, BodyPartType.Groin }
    for i = 1, #bodyPartsList do
        local partType = bodyPartsList[i]
        local part = bodyDamage:getBodyPart(partType)
        local newPain = math.min(part:getAdditionalPain() + rate, maxPain)
        part:setAdditionalPain(newPain)
        syncBodyPart(part, BodyPartSyncPacket.BD_additionalPain)
    end
end


local function addRidingPainToAllPlayers()
    local players = getPlayers()

    for i = 0, players:size() - 1 do
        PlayerDamage.applyRidingPain(players:get(i))
    end
end

Events.OnTick.Add(addRidingPainToAllPlayers)


---@param part BodyPart|nil
---@param bd BodyDamage
---@return nil
local function resetBodyPartDamage(part, bd)
    if not part then
        return
    end

    part:RestoreToFullHealth()
    part:SetInfected(false)
    part:SetFakeInfected(false)
end


---@param character IsoGameCharacter
---@param part BodyPartType
---@param damageType DamageType
local function addPain(character, part, damageType)
    local stats = character:getStats()
    local bodyDamage = character:getBodyDamage()

    local pain = stats:get(CharacterStat.PAIN)
    if damageType == "scratch" then
        pain = bodyDamage:getInitialScratchPain() * BodyPartType.getPainModifyer(BodyPartType.ToIndex(part))
    elseif damageType == "bite" then
        pain = bodyDamage:getInitialBitePain() * BodyPartType.getPainModifyer(BodyPartType.ToIndex(part))
    end

    stats:add(CharacterStat.PAIN, pain)

    if instanceof(character, "IsoPlayer") then
        ---@cast character IsoPlayer
        sendPlayerStat(character, CharacterStat.PAIN)
    end
end


---@param character IsoGameCharacter
---@param partType BodyPartType
local function attemptScratch(character, partType)
    local partIndex = BodyPartType.ToIndex(partType)
    local bloodBodyPart = BloodBodyPartType.FromIndex(partIndex)
    if ZombRand(100) < character:getBodyPartClothingDefense(partIndex, false, false) then
        character:addHoleFromZombieAttacks(bloodBodyPart, true)

        return false
    end

    local part = character:getBodyDamage():getBodyPart(partType)
    part:AddDamage(
        ZombRandFloat(PlayerDamage.DMG_SCR_MIN, PlayerDamage.DMG_SCR_MAX)
    )
    part:setScratched(true, false)
    syncBodyPart(
        part,
        BodyPartSyncPacket.BD_Health + BodyPartSyncPacket.BD_scratched
    )

    character:addBlood(
        bloodBodyPart,
        true,
        false,
        true
    )
    
    addPain(character, partType, "scratch")

    local emitter = character:getEmitter()
    if emitter then
        emitter:playSoundImpl("ZombieScratch", nil)
    end
end


---@param character IsoGameCharacter
---@param partType BodyPartType
local function attemptLaceration(character, partType)
    local part = character:getBodyDamage():getBodyPart(partType)
    part:AddDamage(
        ZombRandFloat(PlayerDamage.DMG_LAC_MIN, PlayerDamage.DMG_LAC_MAX)
    )
    part:setCut(true)
    syncBodyPart(
        part,
        BodyPartSyncPacket.BD_Health + BodyPartSyncPacket.BD_cut
    )

    character:addBlood(
        BloodBodyPartType.FromIndex(BodyPartType.ToIndex(partType)),
        true,
        false,
        true
    )
    
    addPain(character, partType, "scratch")

    local emitter = character:getEmitter()
    if emitter then
        emitter:playSoundImpl("ZombieScratch", nil)
    end
end


---@param character IsoGameCharacter
---@param partType BodyPartType
local function attemptBite(character, partType)
    local partIndex = BodyPartType.ToIndex(partType)
    local bloodBodyPart = BloodBodyPartType.FromIndex(partIndex)

    if ZombRand(100) < character:getBodyPartClothingDefense(partIndex, true, false) then
        character:addHoleFromZombieAttacks(
            bloodBodyPart, true
        )

        return false
    end

    local part = character:getBodyDamage():getBodyPart(partType)
    part:AddDamage(
        ZombRandFloat(PlayerDamage.DMG_BIT_MIN, PlayerDamage.DMG_BIT_MAX)
    )
    part:SetBitten(true)
    syncBodyPart(
        part,
        BodyPartSyncPacket.BD_Health + BodyPartSyncPacket.BD_bitten
    )

    character:addBlood(bloodBodyPart, false, true, true)
    if partType == BodyPartType.Neck then
        character:addBlood(bloodBodyPart, false, true, true)
        character:addBlood(BloodBodyPartType.Torso_Upper, false, true, false)
        character:splatBloodFloorBig()
        character:splatBloodFloorBig()
        character:splatBloodFloorBig()
    end

    addPain(character, partType, "bite")

    local emitter = character:getEmitter()
    if emitter then
        local biteSound = zombie:getBiteSoundName()
        if partType == BodyPartType.Neck then
            biteSound = "NeckBite"
        end
        emitter:playSoundImpl(biteSound, nil)
    end
end


---@param character IsoGameCharacter
---@param zombie IsoZombie
---@param hitReaction string|nil
---@param parts BodyPartType[]
---@return boolean
function PlayerDamage.addRandomDamageFromZombieOnParts(character, zombie, hitReaction, parts)
    if type(parts) ~= "table" or #parts == 0 then
        return false
    end

    hitReaction = (hitReaction and hitReaction ~= "") and hitReaction or "Bite"

    character:setVariable("hitpvp", false)

    local chanceScratchGate = 15 + (character:getMeleeCombatMod()) -- int1
    local chanceLacerGate = 65 -- int3
    local chanceBiteSave = 85 -- int2

    local side = character:testDotSide(zombie):lower()
    local isBehind = (side == "behind" or side == "back")
    local isSide = (side == "left" or side == "right")

    local attackers = (character:getSurroundingAttackingZombies())
    attackers = math.max(attackers, 1)
    chanceScratchGate = chanceScratchGate - (attackers - 1) * 10
    chanceBiteSave = chanceBiteSave - (attackers - 1) * 30
    chanceLacerGate = chanceLacerGate - (attackers - 1) * 15

    if character:getHitReaction() ~= "EndDeath" then
        local dragThreshold = 3
        local crawlersNear = 1
        if (not character:isGodMod())
            and crawlersNear >= dragThreshold
            and not character:isSitOnGround() then
            chanceScratchGate, chanceBiteSave, chanceLacerGate = 0, 0, 0
            character:setHitReaction("EndDeath")
            character:setDeathDragDown(true)
        else
            character:setHitReaction(hitReaction)
        end
    end

    if isBehind then
        chanceScratchGate = chanceScratchGate - 15
        chanceBiteSave = chanceBiteSave - 25
        chanceLacerGate = chanceLacerGate - 35
        if attackers > 2 then
            chanceBiteSave = chanceBiteSave - 15
            chanceLacerGate = chanceLacerGate - 15
        end
    elseif isSide then
        chanceScratchGate = chanceScratchGate - 30
        chanceBiteSave = chanceBiteSave - 7
        chanceLacerGate = chanceLacerGate - 27
    end

    local isCrawling = zombie:isCrawling()
    if isCrawling and ZombRand(2) ~= 0 then
        return false
    end

    local bpType = parts[ZombRand(#parts) + 1] ---@as BodyPartType
    local bpIndex = BodyPartType.ToIndex(bpType)

    if not isCrawling then
        local bias = 10.0 * attackers + (isBehind and 5.0 or 0) + (isSide and 2.0 or 0)
        if isBehind and ZombRand(100) < bias then
            for i = 1, #parts do
                if parts[i] == BodyPartType.Neck then
                    bpType = BodyPartType.Neck
                    bpIndex = BodyPartType.ToIndex(bpType)
                    break
                end
            end
        end
    end

    if bpType == BodyPartType.Head or bpType == BodyPartType.Neck then
        local keepChance = 70
        if isBehind then
            keepChance = 90
        end
        if isSide then
            keepChance = 80
        end
        if ZombRand(100) > keepChance then
            local filtered = {}
            for i = 1, #parts do
                local t = parts[i]
                if t ~= BodyPartType.Head and t ~= BodyPartType.Neck and t ~= BodyPartType.Groin then
                    filtered[#filtered + 1] = t
                end
            end
            if #filtered > 0 then
                bpType = filtered[ZombRand(#filtered) + 1] ---@as BodyPartType
                bpIndex = BodyPartType.ToIndex(bpType)
            end
        end
    end

    -- FIXME: this doesn't work because we can't access fields this way
    --  what is this even meant to do?
    if zombie.inactive then
        chanceScratchGate = chanceScratchGate + 20
        chanceBiteSave = chanceBiteSave + 20
        chanceLacerGate = chanceLacerGate + 20
    end

    local landed = (ZombRand(100) > chanceScratchGate)
    if not landed then
        return false
    end

    local doScratch = ZombRand(100) > chanceLacerGate
    local doBite = (ZombRand(100) > chanceBiteSave) and (not (zombie:cantBite()))
    local doLacer = (not doScratch) and (not doBite)

    if doScratch then
        attemptScratch(character, bpType)
    elseif doLacer then
        attemptLaceration(character, bpType)
    else
        attemptBite(character, bpType)
    end

    return true
end


---@type BodyPartType[]
local allowedDamageParts = {
    BodyPartType.Foot_L,
    BodyPartType.Foot_R,
    BodyPartType.LowerLeg_L,
    BodyPartType.LowerLeg_R,
    BodyPartType.UpperLeg_L,
    BodyPartType.UpperLeg_R,
    BodyPartType.Groin,
}

---@type table<number, boolean>
local allowedDamagePartIndices = {}
do
    for i = 1, #allowedDamageParts do
        local v = allowedDamageParts[i]
        local idx = (type(v) == "number") and v or BodyPartType.ToIndex(v)
        allowedDamagePartIndices[idx] = true
    end
end

-- FIXME: zombie updates are handled by the zombie's owner, not usually the server!
--  we might need to detect attacks on the client and tell the server when they occur
---@param zombie IsoZombie
---@return nil
function PlayerDamage.onZombieAttack_checkAndRedirect(zombie)
    if not zombie:getVariableBoolean(AnimationVariable.RIDING_HORSE) then
        return
    end

    local target = zombie:getTarget()
    if not target or not instanceof(target, "IsoGameCharacter") then
        return
    end
    ---@cast target IsoGameCharacter

    local outcome = zombie:getVariableString("AttackOutcome")
    if outcome == "" then
        return
    end

    local bodyDamage = target:getBodyDamage()

    -- FIXME: this will heal injuries that were incurred when you were not on the horse
    for i = 0, BodyPartType.MAX:index() - 1 do
        local bpType = BodyPartType.FromIndex(i)
        local part = bodyDamage:getBodyPart(bpType)
        local horse = Mounts.getMount(target)
        if part and (part:bitten() or part:scratched() or part:isCut() or part:bleeding()) then
            if allowedDamagePartIndices[i] then
                return
            end

            resetBodyPartDamage(part, bodyDamage)

            if HorseDamage.tryRedirectZombieHitToHorse(zombie, target, horse) then
                return
            end

            PlayerDamage.addRandomDamageFromZombieOnParts(target, zombie, target:getHitReaction(), allowedDamageParts)
            return
        end
    end

    local removeInfection = true
    for i = 0, BodyPartType.MAX:index() - 1 do
        local bpType = BodyPartType.FromIndex(i)
        local part = bodyDamage:getBodyPart(bpType)
        if part:IsInfected() or part:IsFakeInfected() then
            removeInfection = false
            break
        end
    end

    -- if no body parts are infected anymore, remove body infection
    if removeInfection then
        bodyDamage:setIsFakeInfected(false)
        bodyDamage:setInfected(false)
        bodyDamage:setInfectionTime(-1)
    end
end

Events.OnZombieUpdate.Add(PlayerDamage.onZombieAttack_checkAndRedirect)

return PlayerDamage
