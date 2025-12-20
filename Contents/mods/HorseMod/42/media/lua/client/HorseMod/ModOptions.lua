---Holds the mod option values of the HorseMod.
---@type table<string, any>
local ModOptions = {
    ---Horse sound volume.
    ---@type number
    HorseSoundVolume = 0.4,

    ---Horse jump keybind.
    ---@type integer
    HorseJumpButton = Keyboard.KEY_SPACE,
    
    ---Horse trot switch keybind.
    ---@type integer
    HorseTrotButton = Keyboard.KEY_X,
}


local options = PZAPI.ModOptions:create("HorseMod", "IGUI_ModOptions_HorseModName")

---VOLUME
---@TODO move to the vanilla sound panel
options:addDescription("IGUI_ModOptions_HorseSoundVolume_Desc")

-- tooltip is useless because it can't appear in-game for this type of option
options:addSlider(
    "HorseSoundVolume", 
    "IGUI_ModOptions_HorseSoundVolume_Name", 
    0.01, 1, 0.01, ModOptions.HorseSoundVolume
)

---KEYBINDS
options:addDescription("IGUI_ModOptions_HorseKeybind")
options:addKeyBind(
    "HorseJumpButton", 
    "IGUI_ModOptions_HorseKeybind_Jump_Name", 
    ModOptions.HorseJumpButton, 
    "IGUI_ModOptions_HorseKeybind_Jump_Tooltip"
)
options:addKeyBind(
    "HorseTrotButton",
    "IGUI_ModOptions_HorseKeybind_Trot_Name",
    ModOptions.HorseTrotButton,
    "IGUI_ModOptions_HorseKeybind_Trot_Tooltip"
)

---This is a helper function that will automatically populate the "config" table.
---Retrieve each option from their `ID` with: `config.ID`
function options:apply()
    for k,v in pairs(self.dict) do
        if v.type == "multipletickbox" then
            ---@cast v umbrella.ModOptions.MultipleTickBox
            for i=1, #v.values do
                ModOptions[(k.."_"..tostring(i))] = v:getValue(i)
            end
        elseif v.type ~= "button" then
            ---@diagnostic disable-next-line
            ModOptions[k] = v:getValue()
        end
    end
end

---Init values
Events.OnMainMenuEnter.Add(function()
    options:apply()
end)

return ModOptions