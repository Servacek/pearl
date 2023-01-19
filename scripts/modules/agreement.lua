--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @category FrontEnd


--- @TODO: Check out also 'kleifileexists' as a possible alternative
-- We have already agreed to the agreement and the version of the agreement is the same as
-- the version of the newest released agreement.
local _agr_file_exists = io.exists(PEARL.CONSTS.AGREEMENT_FILE_PATH)
local _agr_file_version = io.line(PEARL.CONSTS.AGREEMENT_FILE_PATH)
if _agr_file_exists and type(PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT) ~= "table" then
    return
end

if type(PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT) == "table" and
    PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT.version and
    PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT.version == _agr_file_version
then
    return
end

local AgreementScreen = PEARL.loadfile("screens/agreementscreen")
local PopupDialogScreen = require("screens/redux/popupdialog")

--------------------------------------
-- [[ Locals ]]
--------------------------------------

local _agreement_displayed = false

local function IsAgreementScreenEnabled()
    return type(PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT) == "table" and #PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT > 0
end

local function IsWelcomeScreenEnabled()
    return type(PEARL.CONFIG.WELCOME_POPUP_CONTENT) == "table" and #PEARL.CONFIG.WELCOME_POPUP_CONTENT > 0
end

local function CreateAgreementCacheFile()
    local agr_file = io.open(PEARL.CONSTS.AGREEMENT_FILE_PATH, "w")
    if not agr_file then
        return PEARL.error("Failed to create the agreement cache file!")
    end

    if IsAgreementScreenEnabled() and PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT.version ~= nil then
        agr_file:write(PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT.version)
    end

    agr_file:close()
end

local function OnPlayerFinishedAgreement(self, agreed)
    self:Close()

    PEARL.ClientNetwork:SendAgreementDataToServer(agreed, not _agr_file_exists)

    if not agreed then
        -- Give a frame to the RPC queue
        return PEARL.Scheduler:ExecuteInTime(0, DoRestart, nil, true)
    end

    CreateAgreementCacheFile()
end

local function ShowAgreement()
    -- The Agreement Screen has no content so do not show it
    if not IsAgreementScreenEnabled() then
        return
    end

    local agreement_screen = AgreementScreen()
    agreement_screen:SetOnContinue(OnPlayerFinishedAgreement)

    TheFrontEnd:PushScreen(agreement_screen)
end

local function OnWelcomeScreenContinue()
    TheFrontEnd:PopScreen()

    if IsAgreementScreenEnabled() then
        return ShowAgreement()
    end

    -- Even though agreement screen is disable we still want to create the agreement file
    -- so the next join the welcome screen doesn't pop-up again.
    -- Note: This file will not have any version - it will be empty.
    CreateAgreementCacheFile()
end

local function ShowWelcomeScreen()
    if not IsWelcomeScreenEnabled() then
        return
    end

    -- Welcome Popup has only one section, so index it directly.
    TheFrontEnd:PushScreen(PopupDialogScreen(PEARL.CONFIG.WELCOME_POPUP_CONTENT[1].title, PEARL.CONFIG.WELCOME_POPUP_CONTENT[1].description, {
        {text = STRINGS.PEARL.UI.INTRO_POPUP_BUTTON_CONTINUE, cb = OnWelcomeScreenContinue}
    }))
end

local function OnPlayerEnteredGame()
    if _agreement_displayed then
        return
    end

    _agreement_displayed = true

    -- We have already accepted the agreement but it was updated
    if _agr_file_exists then
        return ShowAgreement()
    end

    -- We are on the server for the first time.

    if IsWelcomeScreenEnabled() then
        -- Welcome screen should display the agreement on continue
        ShowWelcomeScreen()
    else
        ShowAgreement()
    end
end

PEARL.AddWorldPostInit(function(world)
    -- None will ever read this while in the game.
    -- So try to display the popup only when in the lobby.
    -- Maybe display just the welcome screen?
    -- world:ListenForEvent("playeractivated", OnPlayerEnteredGame)

    -- This is an lobby alternative for playeractivated
    world:ListenForEvent("entercharacterselect", OnPlayerEnteredGame)
end)
