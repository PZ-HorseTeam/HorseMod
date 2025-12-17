if isClient() then
    return
end

local Mounts = {}


---@type table<IsoPlayer, IsoAnimal>
Mounts.playerMountMap = {}

---@type table<IsoAnimal, IsoPlayer>
Mounts.mountPlayerMap = {}


---@param player IsoPlayer
---@param animal IsoAnimal
function Mounts.addMount(player, animal)
    Mounts.playerMountMap[player] = animal
    Mounts.mountPlayerMap[animal] = player
end


---@param player IsoPlayer
function Mounts.removeMount(player)
    local mount = Mounts.playerMountMap[player]
    Mounts.playerMountMap[player] = nil
    Mounts.mountPlayerMap[mount] = nil
end


return Mounts