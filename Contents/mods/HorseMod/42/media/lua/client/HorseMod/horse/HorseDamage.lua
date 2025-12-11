---@class HorseDamage
local HorseDamage = {}


HorseDamage.ZOMBIE_DAMAGE_CHANCE = 35
HorseDamage.ZOMBIE_DAMAGE_MIN = 0.05
HorseDamage.ZOMBIE_DAMAGE_MAX = 0.12


HorseDamage.HORSE_DEATH_KNOCKDOWN_RADIUS = 2.5


---@param horse IsoAnimal
function HorseDamage.knockDownNearbyZombies(horse)
    local cell = getCell()

    local zombies = cell:getZombieList()
    if not zombies or zombies:isEmpty() then
        return
    end

    local hx, hy, hz = horse:getX(), horse:getY(), horse:getZ()
    local rangeSq = HorseDamage.HORSE_DEATH_KNOCKDOWN_RADIUS * HorseDamage.HORSE_DEATH_KNOCKDOWN_RADIUS

    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and zombie.knockDown and zombie:getZ() == hz then
            local dx = zombie:getX() - hx
            local dy = zombie:getY() - hy

            if dx * dx + dy * dy <= rangeSq then
                zombie:knockDown(true)
            end
        end
    end
end


---@nodiscard
---@param min number
---@param max number
---@return number
local function randf(min, max)
    return min + (ZombRand(1000) / 1000.0) * (max - min)
end


---@param horse IsoAnimal
---@param value number
---@return number
function HorseDamage.setHealth(horse, value)
    local newValue = math.max(0, value)
    horse:setHealth(newValue)

    return newValue
end


---@param horse IsoAnimal
---@return number
local function applyZombieDamage(horse)
    local damage = randf(HorseDamage.ZOMBIE_DAMAGE_MIN, HorseDamage.ZOMBIE_DAMAGE_MAX)

    return HorseDamage.setHealth(horse, horse:getHealth() - damage)
end


---@param zombie IsoGameCharacter|nil
---@param player IsoPlayer|nil
---@param horse IsoAnimal|nil
---@return boolean
function HorseDamage.tryRedirectZombieHitToHorse(zombie, player, horse)
    if not zombie or not player then
        return false
    end

    if not horse then
        return false
    end

    if ZombRand(100) >= HorseDamage.ZOMBIE_DAMAGE_CHANCE then
        return false
    end

    applyZombieDamage(horse)

    return true
end


return HorseDamage
