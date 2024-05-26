--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @category FrontEnd

--- @TODO: Create some extensible json client-side persistence system.
--- Maybe even make it also server-side?
--- @TODO: Make agreement screen and welcome popup stand out from all the other popups.
--- @TODO: Fix the bug with the agreement screen not closing properly.

--[[
    So, an intro screen has these four following states:
        1. Not Shown At All (AGREEMENT file doesn't exist)

--]]

local AgreementScreen = PEARL.loadfile("screens/agreementscreen")

local PopupDialogScreen = require("screens/redux/popupdialog")

--------------------------------------
-- [[ Function Declarations ]]
--------------------------------------

local OnPlayerEnteredGame
local ShowAgreement, HideAgreement, CloseAgreement

--------------------------------------
-- [[ Locals ]]
--------------------------------------

local _t_agreementstart

-- This module should have only one screen displayed at a time.
local _active_screen
local _agreement_screen

local _finished = false

--------------------------------------
-- [[ Local Functions ]]
--------------------------------------

local function CloseActiveScreen()
    PEARL.debug("CloseActiveScreen")
    if _active_screen then
        if _active_screen == _agreement_screen then
            PEARL.warn("CLOSING AGREEMENT")
        end

        TheFrontEnd:PopScreen(_active_screen)

        _active_screen = nil
    end
end

local function ShowScreen(screen)
    PEARL.debug("ShowScreen")
    CloseActiveScreen()

    _active_screen = screen
    screen:Show()

    return TheFrontEnd:PushScreen(_active_screen)
end

local function HideScreen(screen)
    PEARL.debug("HideScreen")
    _active_screen = nil
    screen:Hide()

    return TheFrontEnd:PopScreen(_active_screen)
end

local function OnPlayerFinishedAgreement(data)
    CloseAgreement()

    if _finished then
        return
    end

    _finished = true

    local agreed = data.agreed or false
    local agreedintime = agreed and (os.time() - (_t_agreementstart or 0)) or nil
    local agreed_version = PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT.version
    local datacollection = data.datacollection or false

    PEARL.AgreementManager:SyncAgreementDataWithServer(
        agreed, datacollection, agreedintime, agreed_version
    )
end

local function OnDisagreeConfirmed(data)
    PEARL.debug("OnDisagreeConfirmed")
    OnPlayerFinishedAgreement(data)

    PEARL.StaticScheduler:ExecuteInTime(0, function()
        PEARL.ClientNetwork:ForceDisconnectWithReason("ID_DST_USER_DISAGREED", false, true)
    end)
end

local function WarnOnDecline(data)
    PEARL.debug("WarnOnDecline")

    return ShowScreen(PopupDialogScreen(
        STRINGS.PEARL.UI.AGREEMENT_DECLINE_POPUP_TITLE,
        STRINGS.PEARL.UI.AGREEMENT_DECLINE_POPUP_BODY,
        {
            {
                text = STRINGS.PEARL.UI.AGREEMENT_DECLINE_BUTTON_YES,
                cb = function()
                    OnDisagreeConfirmed(data)
                end,
            },
            {
                text = STRINGS.PEARL.UI.AGREEMENT_DECLINE_BUTTON_NO,
                -- Go back
                cb = ShowAgreement,
            }
        }
    ))
end

local function OnAgreed(data)
    OnPlayerFinishedAgreement(data)

    PEARL.AgreementManager:UpdateFile() -- Only save the record when we have agreed.
end

local function OnAgreementContinue(self, data)
    if data.agreed == true then
        return OnAgreed(data)
    end

    -- HideAgreement()
    WarnOnDecline(data)
end

local function CreateAgreementScreen()
    if _agreement_screen then
        return PEARL.error("Agreement screen already exists!")
    end

    _agreement_screen = AgreementScreen()
    _agreement_screen:SetOnContinue(OnAgreementContinue)
end

CloseAgreement = function()
    if not _agreement_screen then
        return
    end

    if _active_screen == _agreement_screen then
        _active_screen = nil
    end

    _agreement_screen:DoClose()
end

HideAgreement = function()
    PEARL.debug("HideAgreement")
    if not _agreement_screen then
        CreateAgreementScreen()
    end

    HideScreen(_agreement_screen)
end

ShowAgreement = function()
    PEARL.debug("ShowAgreement")
    -- Create only one agreement screen per session.
    if not _agreement_screen then
        CreateAgreementScreen()
    end

    if not _t_agreementstart then -- Do not reset, everything counts
        _t_agreementstart = os.time()
    end

    return ShowScreen(_agreement_screen)
end

local function NotifyAgreementUpdate()
    return ShowScreen(PopupDialogScreen(
        STRINGS.PEARL.UI.AGREEMENT_UPDATED_POPUP_TITLE,
        STRINGS.PEARL.UI.AGREEMENT_UPDATED_POPUP_BODY,
        {{
            text = STRINGS.PEARL.UI.AGREEMENT_UPDATED_POPUP_CONTINUE,
            cb = ShowAgreement,
        }}
    ))
end

local function OnContinue(self)
    CloseActiveScreen()

    if not PEARL.AgreementManager:IsAgreementScreenEnabled() then
        return
    end

    if PEARL.AgreementManager:AgreementDisplayed() then
        return NotifyAgreementUpdate()
    end

    return ShowAgreement()
end

local function ShowWelcomeScreen()
    -- Welcome Popup has only one section, so index it directly.
    return FrontEnd:InsertScreenAtIndex(PopupDialogScreen(
        PEARL.CONFIG.WELCOME_POPUP_CONTENT[1].title,
        PEARL.CONFIG.WELCOME_POPUP_CONTENT[1].description,
        {{
            text = STRINGS.PEARL.UI.INTRO_POPUP_BUTTON_CONTINUE,
            cb = OnContinue
        }}
    ), 1)
end

local function ClearWorldCallbacks(world)
    world:RemoveEventCallback("playeractivated", OnPlayerEnteredGame)
    world:RemoveEventCallback("entercharacterselect", OnPlayerEnteredGame)
end

OnPlayerEnteredGame = function(world)
    -- So we do not display this multiple times per one instance.
    ClearWorldCallbacks(world)

    -- Wait a tick here so everything is ready when we show the screen.
    PEARL.StaticScheduler:ExecuteInTime(0, function()
        if PEARL.AgreementManager:IsWelcomePopupEnabled() and not PEARL.AgreementManager:AgreementDisplayed() then
            return ShowWelcomeScreen()
        end

        return OnContinue()
    end)
end

local function OnConnectionAllowed(data)
    if data.first_time_joined == true and PEARL.AgreementManager:HasRecord() then
        local version = PEARL.AgreementManager:GetLocalVersion()

        PEARL.AgreementManager:SyncAgreementDataWithServer(
            true, true, nil, version
        )
    end
end

--------------------------------------
-- [[ Setup ]]
--------------------------------------

-- If we have already accepted the agreement and the version was the same as the newest one.
if PEARL.AgreementManager:IsEnabled() and not PEARL.AgreementManager:IsUpToDate() then
    PEARL.AddWorldPostInit(function(world)
        -- None will ever read this while in the game.
        -- So try to display the popup only when in the lobby.
        -- world:ListenForEvent("playeractivated", OnPlayerEnteredGame)

        -- This is an lobby alternative for playeractivated
        world:ListenForEvent("entercharacterselect", OnPlayerEnteredGame)
    end)
end

PEARL.EventProcessor:AddSafeEventHandler("connection_allowed", OnConnectionAllowed)
