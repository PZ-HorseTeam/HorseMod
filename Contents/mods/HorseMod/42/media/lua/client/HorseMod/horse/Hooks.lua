local HorseUtils = require("HorseMod/Utils")
local AnimationVariables = require("HorseMod/AnimationVariables")

-- Hook ISAnimalUI to setup our animation when it's a horse

local old_create = ISAnimalUI.create

local function setHorseAvatarVariables(avatar)
    if not avatar or not avatar.setVariable or not avatar.animal then return end
    if not HorseUtils.isHorse(avatar.animal) then return end
    local walk, gallop = GetSpeeds()
    avatar:setVariable(AnimationVariables.IS_HORSE, true)
    avatar:setVariable(AnimationVariables.WALK_SPEED, walk)
    avatar:setVariable(AnimationVariables.RUN_SPEED, gallop)
end

---@diagnostic disable-next-line: duplicate-set-field
ISAnimalUI.create = function(self)
    old_create(self)
    local walk, gallop = GetSpeeds()
    if HorseUtils.isHorse(self.animal) then
        self.avatarPanel:setVariable(AnimationVariables.IS_HORSE, true)
        self.avatarPanel:setVariable(AnimationVariables.WALK_SPEED, walk)
        self.avatarPanel:setVariable(AnimationVariables.RUN_SPEED, gallop)
    end
end

local old_vehicleCreate = ISVehicleAnimalUI.create

---@diagnostic disable-next-line: duplicate-set-field
function ISVehicleAnimalUI:create(reset)
    old_vehicleCreate(self, reset)
    for _, animalPanel in ipairs(self.scrollPanel.avatars) do
        setHorseAvatarVariables(animalPanel.avatar)
    end
end

-- FIXME: hook ISAnimalUI to fix too long names (American Quarter Stallion) partially covering the Rename button
