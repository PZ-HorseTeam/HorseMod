---@namespace HorseMod

require("HorseMod/ModOptions")

local horseSoundVolumeOption = PZAPI.ModOptions:getOptions("HorseMod"):getOption("HorseSoundVolume")
---@cast horseSoundVolumeOption umbrella.ModOptions.Slider


local HorseSoundVolume = {}


---@return number
---@nodiscard
local function getSliderValue()
    local element = horseSoundVolumeOption.element
    if element then
        return element:getCurrentValue()
    end
    return horseSoundVolumeOption.value
end


---@return number
---@nodiscard
function HorseSoundVolume.getLive()
    return getCore():getOptionSoundVolume() * 0.1 * getSliderValue()
end


return HorseSoundVolume
