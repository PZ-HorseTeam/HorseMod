local POPUP_WIDTH = 950
local POPUP_HEIGHT = 450
local CORE = getCore()
local STAMP_KEY = "horsemod"
local PLAYER_FLAG = "horseModOldSaveWarningSeen"

local playerReady = false
local popupShown = false

local function make_popup(text, onclick)
    -- local width = getTextManager():MeasureStringX(UIFont.Small, text) + 20
    -- i wanted to colour the text, but this doesn't use ISRichTextPanel :(
    -- yea and me I wanted to add an image to it HAAAAAAAAAAAAAAAAA
    local popup = ISCollapsableModalRichText:new(
        (CORE:getScreenWidth() - POPUP_WIDTH) / 2,
        (CORE:getScreenHeight() - POPUP_HEIGHT) / 2,
        POPUP_WIDTH,
        POPUP_HEIGHT,
        text,
        false,
        nil,
        onclick,
        0
    )
    popup.backgroundColor = {r=0, g=0, b=0, a=0.8}
    popup:setAlwaysOnTop(true)
    popup:initialise()
    popup:addToUIManager()
    setGameSpeed(0)
end

local function ackPopup()
    local player = getPlayer()
    if not player then return end
    local pmd = player:getModData()
    pmd[PLAYER_FLAG] = true

    if isClient() then
        player:transmitModData()
    elseif isServer() then
        return
    else
        return
    end
end

local function tryShowOldSaveWarning()
    if not playerReady then return end
    if popupShown then return end

    local modData = ModData.getOrCreate(STAMP_KEY)
    if modData.worldStamped == nil then return end
    if modData.worldStamped == true then return end

    local player = getPlayer()
    if not player then return end
    if player:getModData()[PLAYER_FLAG] == true then return end

    if isClient() then
        if not isAdmin() then return end
    elseif isServer() then
        return
    else
    end

    popupShown = true
    local text = getText("IGUI_HorseMod_OldSaveWarning")
    make_popup(text, ackPopup)
end

function check_meatball()
    local animViewer = AnimationViewerState.checkInstance()

    local clips = animViewer:fromLua1("getClipNames", "HorseMod.Stallion")
    local size = clips:size()
    animViewer:fromLua0('exit')

    if size > 0 then return end

    local text = getText("IGUI_HorseMod_MeatballWarning")
    make_popup(text)
end

local function onCreatePlayer()
    playerReady = true

    if isClient() then
        ModData.request(STAMP_KEY)
    elseif isServer() then
    else
    end

    tryShowOldSaveWarning()
end

Events.OnCreatePlayer.Add(onCreatePlayer)

local function onReceiveGlobalModData(tag, receivedTable)
    if tag ~= STAMP_KEY then return end
    if receivedTable then
        local local_table = ModData.getOrCreate(tag)
        for k, v in pairs(receivedTable) do
            local_table[k] = v
        end
    end
    tryShowOldSaveWarning()
end

Events.OnReceiveGlobalModData.Add(onReceiveGlobalModData)

local function onGameStart()
    tryShowOldSaveWarning()
    check_meatball()
end

Events.OnGameStart.Add(onGameStart)
