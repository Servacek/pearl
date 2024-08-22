--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


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
local ShowAgreement, CloseAgreement

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
    --CloseActiveScreen()

    _active_screen = screen
    screen:Show()

    return TheFrontEnd:PushScreen(_active_screen)
end

local function OnPlayerFinishedAgreement(data)
    CloseAgreement()

    if _finished then
        return
    end
    _finished = true

    PEARL.AgreementManager:AgreementFinished(data)
    PEARL.AgreementManager:SyncAgreementDataWithServer()
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

    local popup
    popup = TheFrontEnd:PushScreen(PopupDialogScreen(
        STRINGS.PEARL.UI.AGREEMENT_DECLINE_POPUP_TITLE,
        STRINGS.PEARL.UI.AGREEMENT_DECLINE_POPUP_BODY,
        {
            {
                text = STRINGS.PEARL.UI.AGREEMENT_DECLINE_BUTTON_YES,
                cb = function() OnDisagreeConfirmed(data) end,
            },
            {
                text = STRINGS.PEARL.UI.AGREEMENT_DECLINE_BUTTON_NO,
                cb = function() TheFrontEnd:PopScreen(popup) end,
            }
        }
    ))
end

local function OnAgreementContinue(self, data)
    if data.agreed == true then
        return OnPlayerFinishedAgreement(data)
    end

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

ShowAgreement = function()
    PEARL.debug("ShowAgreement")
    -- Create only one agreement screen per session.
    if not _agreement_screen then
        CreateAgreementScreen()
    end

    PEARL.AgreementManager:AgreementAutoDisplayed()
    return TheFrontEnd:PushScreen(_agreement_screen)
end

local function NotifyAgreementUpdate()
    local popup
    popup = TheFrontEnd:PushScreen(PopupDialogScreen(
        STRINGS.PEARL.UI.AGREEMENT_UPDATED_POPUP_TITLE,
        STRINGS.PEARL.UI.AGREEMENT_UPDATED_POPUP_BODY,
        {{
            text = STRINGS.PEARL.UI.AGREEMENT_UPDATED_POPUP_CONTINUE,
            cb = function()
                ShowAgreement()
                TheFrontEnd:PopScreen(popup)
            end,
        }}
    ))
end

local function OnContinue()
    if PEARL.AgreementManager:IsAgreementScreenEnabled() and not _finished then
        if PEARL.AgreementManager:WasAgreementDisplayed() then
            return NotifyAgreementUpdate()
        end

        return ShowAgreement()
    end
end

local function ShowWelcomeScreen()
    PEARL.STORAGE.welcome_dialog = PEARL.STORAGE.welcome_dialog or {}
    PEARL.STORAGE.welcome_dialog.displayed = true

    -- Welcome Popup has only one section, so index it directly.
    local popup
    popup = FrontEnd:InsertScreenAtIndex(PopupDialogScreen(
        PEARL.CONFIG.WELCOME_POPUP_CONTENT[1].title,
        PEARL.CONFIG.WELCOME_POPUP_CONTENT[1].description,
        {{
            text = STRINGS.PEARL.UI.INTRO_POPUP_BUTTON_CONTINUE,
            cb = function()
                TheFrontEnd:PopScreen(popup)
                OnContinue()
            end
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
        if (not PEARL.AgreementManager:WasWelcomePopupDisplayed() and
            PEARL.AgreementManager:IsWelcomePopupEnabled() and
            PEARL.ClientNetwork:JoinedFirstTime() and
            not PEARL.AgreementManager:WasAgreementDisplayed()
        ) then
            return ShowWelcomeScreen()
        end

        return OnContinue()
    end)
end

local function OnConnectionAllowed(data)
    if data.first_time_joined == true and PEARL.AgreementManager:HasRecord() then
        PEARL.AgreementManager:SyncAgreementDataWithServer()
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
