---@namespace HorseMod

---REQUIREMENTS
local random_instance = newrandom()

---@class HorseDamage
local HorseDamage = {}


HorseDamage.ZOMBIE_DAMAGE_CHANCE = 100
HorseDamage.ZOMBIE_DAMAGE_MIN = 0.3
HorseDamage.ZOMBIE_DAMAGE_MAX = 0.6


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
        if zombie:getZ() == hz then
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
    return min + random_instance:random() * (max - min)
end


---@param horse IsoAnimal
local function applyZombieDamage(horse)
    local damage = randf(HorseDamage.ZOMBIE_DAMAGE_MIN, HorseDamage.ZOMBIE_DAMAGE_MAX)

    horse:setHealth(math.max(horse:getHealth() - damage, 0))
end


---@param zombie IsoGameCharacter
---@param player IsoPlayer
---@param horse IsoAnimal
---@return boolean
function HorseDamage.tryRedirectZombieHitToHorse(zombie, player, horse)
    if ZombRand(100) >= HorseDamage.ZOMBIE_DAMAGE_CHANCE then
        return false
    end

    applyZombieDamage(horse)

    return true
end


return HorseDamage
