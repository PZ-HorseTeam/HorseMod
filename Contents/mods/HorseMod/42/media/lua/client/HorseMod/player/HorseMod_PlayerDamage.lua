local HorseRiding = require("HorseMod/shared/HorseMod_Riding")
local HorseUtils = require("HorseMod/HorseMod_Utils")

-- maximum pain allowed on each affected body part
local MAX_PAIN_BAREBACK = 20
local MAX_PAIN_SADDLE = 10
-- pain per update while riding without a saddle
local PAIN_RATE_BAREBACK = 0.003
-- pain per update while riding with a saddle
local PAIN_RATE_SADDLE = 0.001

local function applyRidingPain(player)
    local horse = HorseRiding.getMountedHorse and HorseRiding.getMountedHorse(player)
    if not horse then return end
    if not player:getVariableBoolean("pressedmovement") then return end
    local rate = HorseUtils.horseHasSaddleItem(horse) and PAIN_RATE_SADDLE or PAIN_RATE_BAREBACK
    local maxPain = HorseUtils.horseHasSaddleItem(horse) and MAX_PAIN_SADDLE or MAX_PAIN_BAREBACK
    local bd = player:getBodyDamage()
    local bodyPartsList = {BodyPartType.UpperLeg_L, BodyPartType.UpperLeg_R, BodyPartType.Groin}
    for i = 1, #bodyPartsList do
        local partType = bodyPartsList[i]
        local part = bd:getBodyPart(partType)
        if part then
            local newPain = math.min(part:getAdditionalPain() + rate, maxPain)
            part:setAdditionalPain(newPain)
        end
    end
end
Events.OnPlayerUpdate.Add(applyRidingPain)

local _ZombieHitGate = {}

local function randf(min, max)
    return min + (ZombRand(1000) / 1000.0) * (max - min)
end

local DMG_SCR_MIN, DMG_SCR_MAX = 0.15, 0.6   -- scratch
local DMG_LAC_MIN, DMG_LAC_MAX = 0.5,  1.3   -- laceration
local DMG_BIT_MIN, DMG_BIT_MAX = 1.8,  3.2   -- bite

local function addRandomDamageFromZombieOnParts(zombie, hitReaction, parts)
    local player = getSpecificPlayer(0)
    if not player or not zombie then return false end
    if type(parts) ~= "table" or #parts == 0 then return false end

    hitReaction = (hitReaction and hitReaction ~= "") and hitReaction or "Bite"

    player:setVariable("hitpvp", false)

    if isServer() then
        if zombie.OnlineID then
            player:sendObjectChange("AddRandomDamageFromZombie", { zombie = zombie.OnlineID })
        end
        return true
    end

    local chanceScratchGate = 15 + (player.getMeleeCombatMod and player:getMeleeCombatMod() or 0) -- int1
    local chanceLacerGate   = 65  -- int3
    local chanceBiteSave    = 85  -- int2

    local side = tostring(player:testDotSide(zombie) or ""):lower()
    local isBehind = (side == "behind" or side == "back")
    local isSide   = (side == "left" or side == "right")

    local attackers = (player.getSurroundingAttackingZombies and player:getSurroundingAttackingZombies() or 1)
    attackers = math.max(attackers, 1)
    chanceScratchGate = chanceScratchGate - (attackers - 1) * 10
    chanceBiteSave    = chanceBiteSave    - (attackers - 1) * 30
    chanceLacerGate   = chanceLacerGate   - (attackers - 1) * 15

    if player.getHitReaction and player:getHitReaction() ~= "EndDeath" then
        local dragThreshold = 3
        local crawlersNear  = 1
        if (not (player.isGodMod and player:isGodMod()))
            and crawlersNear >= dragThreshold
            and not (player.isSitOnGround and player:isSitOnGround()) then
            chanceScratchGate, chanceBiteSave, chanceLacerGate = 0, 0, 0
            if player.setHitReaction   then player:setHitReaction("EndDeath") end
            if player.setDeathDragDown then player:setDeathDragDown(true)     end
        else
            if player.setHitReaction then player:setHitReaction(hitReaction) end
        end
    end

    if isBehind then
        chanceScratchGate = chanceScratchGate - 15
        chanceBiteSave    = chanceBiteSave    - 25
        chanceLacerGate   = chanceLacerGate   - 35
        if attackers > 2 then
            chanceBiteSave  = chanceBiteSave  - 15
            chanceLacerGate = chanceLacerGate - 15
        end
    elseif isSide then
        chanceScratchGate = chanceScratchGate - 30
        chanceBiteSave    = chanceBiteSave    - 7
        chanceLacerGate   = chanceLacerGate   - 27
    end

    local isCrawling = (zombie.isCrawling and zombie:isCrawling()) or zombie.bCrawling
    if isCrawling and ZombRand(2) ~= 0 then
        return false
    end

    local bpType  = parts[ZombRand(#parts) + 1]
    local bpIndex = BodyPartType.ToIndex(bpType)

    if not isCrawling then
        local bias = 10.0 * attackers + (isBehind and 5.0 or 0) + (isSide and 2.0 or 0)
        if isBehind and ZombRand(100) < bias then
            for i = 1, #parts do
                if parts[i] == BodyPartType.Neck then
                    bpType  = BodyPartType.Neck
                    bpIndex = BodyPartType.ToIndex(bpType)
                    break
                end
            end
        end
    end

    if bpType == BodyPartType.Head or bpType == BodyPartType.Neck then
        local keepChance = 70
        if isBehind then keepChance = 90 end
        if isSide   then keepChance = 80 end
        if ZombRand(100) > keepChance then
            local filtered = {}
            for i = 1, #parts do
                local t = parts[i]
                if t ~= BodyPartType.Head and t ~= BodyPartType.Neck and t ~= BodyPartType.Groin then
                    filtered[#filtered+1] = t
                end
            end
            if #filtered > 0 then
                bpType  = filtered[ZombRand(#filtered) + 1]
                bpIndex = BodyPartType.ToIndex(bpType)
            end
        end
    end

    if zombie.inactive then
        chanceScratchGate = chanceScratchGate + 20
        chanceBiteSave    = chanceBiteSave    + 20
        chanceLacerGate   = chanceLacerGate   + 20
    end

    local landed = (ZombRand(100) > chanceScratchGate)
    if not landed then return false end

    local doScratch = ZombRand(100) > chanceLacerGate
    local doBite    = (ZombRand(100) > chanceBiteSave) and (not (zombie.cantBite and zombie:cantBite()))
    local doLacer   = (not doScratch) and (not doBite)

    local dmg
    local outcomeCode = 0
    local bd = player:getBodyDamage()

    local scratchDef = player.getBodyPartClothingDefense and player:getBodyPartClothingDefense(bpIndex, false, false) or 0
    local biteDef    = player.getBodyPartClothingDefense and player:getBodyPartClothingDefense(bpIndex, true,  false) or 0

    if doScratch then
        if ZombRand(100) < scratchDef then
            player:addHoleFromZombieAttacks(BloodBodyPartType.FromIndex(bpIndex), true)
            return false
        end
        dmg = randf(DMG_SCR_MIN, DMG_SCR_MAX)
        bd:AddDamage(bpIndex, dmg)
        bd:SetScratched(bpIndex, true)
        player:addBlood(BloodBodyPartType.FromIndex(bpIndex), true, false, true)
        outcomeCode = 1
        if player.getEmitter and player:getEmitter() then
            player:getEmitter():playSoundImpl("ZombieScratch", nil)
        end

    elseif doLacer then
        dmg = randf(DMG_LAC_MIN, DMG_LAC_MAX)
        bd:AddDamage(bpIndex, dmg)
        bd:SetCut(bpIndex, true)
        player:addBlood(BloodBodyPartType.FromIndex(bpIndex), true, false, true)
        outcomeCode = 1
        if player.getEmitter and player:getEmitter() then
            player:getEmitter():playSoundImpl("ZombieScratch", nil)
        end

    else
        if ZombRand(100) < biteDef then
            player:addHoleFromZombieAttacks(BloodBodyPartType.FromIndex(bpIndex), true)
            return false
        end
        dmg = randf(DMG_BIT_MIN, DMG_BIT_MAX)
        if player.getEmitter and player:getEmitter() then
            local biteSound = zombie.getBiteSoundName and zombie:getBiteSoundName() or "ZombieBite"
            if bpType == BodyPartType.Neck then biteSound = "NeckBite" end
            player:getEmitter():playSoundImpl(biteSound, nil)
        end
        bd:AddDamage(bpIndex, dmg)
        bd:SetBitten(bpIndex, true)
        player:addBlood(BloodBodyPartType.FromIndex(bpIndex), false, true, true)
        if bpType == BodyPartType.Neck then
            player:addBlood(BloodBodyPartType.FromIndex(bpIndex), false, true, true)
            player:addBlood(BloodBodyPartType.Torso_Upper, false, true, false)
            if player.splatBloodFloorBig then
                player:splatBloodFloorBig(); player:splatBloodFloorBig(); player:splatBloodFloorBig()
            end
        end
        outcomeCode = 2
    end

    local stats = player.getStats and player:getStats()
    if stats then
        local pain = stats:getPain()
        if     outcomeCode == 0 and player.getInitialThumpPain   then pain = pain + player:getInitialThumpPain()   * BodyPartType.getPainModifyer(bpIndex)
        elseif outcomeCode == 1 and player.getInitialScratchPain then pain = pain + player:getInitialScratchPain() * BodyPartType.getPainModifyer(bpIndex)
        elseif outcomeCode == 2 and player.getInitialBitePain    then pain = pain + player:getInitialBitePain()    * BodyPartType.getPainModifyer(bpIndex)
        end
        if pain > 100.0 then pain = 100.0 end
        stats:setPain(pain)
    end

    if instanceof(player, "IsoPlayer") and isClient() and player:isLocalPlayer() then
        if player.updateMovementRates then player:updateMovementRates() end
        if GameClient and GameClient.sendPlayerInjuries then GameClient.sendPlayerInjuries(player) end
        if GameClient and GameClient.sendPlayerDamage   then GameClient.sendPlayerDamage(player)   end
    end

    return true
end

local allowedDamageParts = allowedDamageParts or {
    BodyPartType.Foot_L,
    BodyPartType.Foot_R,
    BodyPartType.LowerLeg_L,
    BodyPartType.LowerLeg_R,
    BodyPartType.UpperLeg_L,
    BodyPartType.UpperLeg_R,
    BodyPartType.Groin,
}

local allowedDamagePartIndices = {}
do
    for i = 1, #allowedDamageParts do
        local v = allowedDamageParts[i]
        local idx = (type(v) == "number") and v or BodyPartType.ToIndex(v)
        allowedDamagePartIndices[idx] = true
    end
end

local function onZombieAttack_checkAndRedirect(zombie)
    if not zombie then return end
    if not getSpecificPlayer(0):getVariableBoolean("RidingHorse") then return end
    local target = zombie:getTarget()
    if not target then return end

    local outcome = zombie:getVariableString("AttackOutcome")
    if not outcome or outcome == "" then return end

    local bd = target.getBodyDamage and target:getBodyDamage()
    if not bd then return end

    for i = 0, BodyPartType.MAX:index() - 1 do
        local bpType = BodyPartType.FromIndex(i)
        local part = bd:getBodyPart(bpType)
        if part and (part:bitten() or part:scratched() or part:isCut() or part:bleeding()) then
            if allowedDamagePartIndices[i] then
                return
            end

            part:RestoreToFullHealth()
            if part.SetInfected            then part:SetInfected(false) end
            if part.SetFakeInfected        then part:SetFakeInfected(false) end
            if bd.setInfectionLevel        then bd:setInfectionLevel(0) end
            if bd.setInfectionTime         then bd:setInfectionTime(-1) end
            if bd.setInfectionMortalityDuration then bd:setInfectionMortalityDuration(-1) end

            if addRandomDamageFromZombieOnParts then
                addRandomDamageFromZombieOnParts(zombie, target:getHitReaction(), allowedDamageParts)
            end
            return
        end
    end
end

Events.OnZombieUpdate.Add(onZombieAttack_checkAndRedirect)

return {}