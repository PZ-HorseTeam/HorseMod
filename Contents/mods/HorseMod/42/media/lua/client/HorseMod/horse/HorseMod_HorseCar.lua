-- local HorseRiding = require("HorseMod/shared/HorseMod_Riding")

-- local _lastHorseByPid = {}
-- -- Events.OnPlayerUpdate.Add(function(player)
-- --     if not player then return end
-- --     local h = HorseRiding.getMountedHorse and HorseRiding.getMountedHorse(player)
-- --     if h and h.isExistInTheWorld and h:isExistInTheWorld() then
-- --         _lastHorseByPid[player:getPlayerNum()] = h
-- --     end
-- -- end)

-- local function vehicleAt(x, y, z)
--     if getVehicleAt then
--         local v = getVehicleAt(x, y)
--         if v then return v end
--     end
--     local sq = getCell():getGridSquare(x, y, z)
--     if sq and sq.getVehicleContainer then
--         local v2 = sq:getVehicleContainer()
--         if v2 then return v2 end
--     end
--     return nil
-- end

-- local function seatLastMountedHorseSeat1(player)
--     local pid   = player:getPlayerNum()
--     local horse = (HorseRiding.getMountedHorse and HorseRiding.getMountedHorse(player)) or _lastHorseByPid[pid]

--     local x = math.floor(player:getX())
--     local y = math.floor(player:getY())
--     local z = player:getZ()
--     local vehicle = vehicleAt(x, y, z) or getCell():getGridSquare(x, y, z):getVehicleContainer()

--     if HorseRiding.dismountHorse then HorseRiding.dismountHorse(player) end

--     local offset = (Vector3f and Vector3f.new) and Vector3f.new(0,0,0) or nil

--     vehicle:setPassenger(1, horse, offset)
--     vehicle:addAnimalInTrailer(horse)
-- end

-- return { seatLastMountedHorseSeat1 = seatLastMountedHorseSeat1 }
