if not isClient() then
    return
end

local POPUP_HEIGHT = 120
local CORE = getCore()

-- Events.OnGameStart.Add(function()
--     local text = getText("IGUI_HorseMod_MultiplayerWarning")

--     local width = getTextManager():MeasureStringX(UIFont.Small, text) + 20
--     -- i wanted to colour the text, but this doesn't use ISRichTextPanel :(
--     local popup = ISModalDialog:new(
--         (CORE:getScreenWidth() - width) / 2,
--         (CORE:getScreenHeight() - POPUP_HEIGHT) / 2,
--         width,
--         POPUP_HEIGHT,
--         text,
--         false
--     )
--     popup:initialise()
--     popup:addToUIManager()
-- end)
