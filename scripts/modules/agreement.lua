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
--- @TODO: Display the modification time on the agreement.

local AgreementScreen = PEARL.loadfile("screens/agreementscreen")

local PopupDialogScreen = require("screens/redux/popupdialog")

--------------------------------------
-- [[ Function Declarations ]]
--------------------------------------

local OnPlayerEnteredGame
local ShowAgreement

--------------------------------------
-- [[ Locals ]]
--------------------------------------

local _t_agreementstart = 0

-- This module should have only one screen displayed at a time.
local _active_screen

--------------------------------------
-- [[ Local Functions ]]
--------------------------------------

local function CloseActiveScreen()
    if _active_screen then
        TheFrontEnd:PopScreen(_active_screen)
        _active_screen = nil
    end
end

local function ShowScreen(screen)
    CloseActiveScreen()

    _active_screen = screen
    return TheFrontEnd:PushScreen(_active_screen)
end

local function WarnOnDecline()
    return ShowScreen(PopupDialogScreen(
        STRINGS.PEARL.UI.AGREEMENT_DECLINE_POPUP_TITLE,
        STRINGS.PEARL.UI.AGREEMENT_DECLINE_POPUP_BODY,
        {
            {
                text = STRINGS.PEARL.UI.AGREEMENT_DECLINE_BUTTON_YES,
                cb = function()
                    PEARL.StaticScheduler:ExecuteInTime(
                        0, PEARL.ClientNetwork.Disconnect, nil, PEARL.ClientNetwork, "ID_DST_USER_DISAGREED", false, true
                    )
                end,
            },
            {
                text = STRINGS.PEARL.UI.AGREEMENT_DECLINE_BUTTON_NO,
                cb = function()
                    -- Go back!
                    ShowAgreement()
                end,
            }

        }
    ))
end

local function OnPlayerFinishedAgreement(self, agreed)
    CloseActiveScreen()

    local agreedintime = agreed and os.difftime(_t_agreementstart, os.time()) or nil
    PEARL.SendRPCToServer(PEARL.RPC.AgreementFinished, agreed, agreedintime)

    if not agreed then
        return WarnOnDecline()
    end

    -- Only save the record when we have agreed.
    PEARL.AgreementManager:UpdateFile()
end

ShowAgreement = function()
    CloseActiveScreen()

    local agreement_screen = AgreementScreen()
    agreement_screen:SetOnContinue(OnPlayerFinishedAgreement)

    _t_agreementstart = os.time()

    return ShowScreen(agreement_screen)
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
    return ShowScreen(PopupDialogScreen(
        PEARL.CONFIG.WELCOME_POPUP_CONTENT[1].title,
        PEARL.CONFIG.WELCOME_POPUP_CONTENT[1].description,
        {{
            text = STRINGS.PEARL.UI.INTRO_POPUP_BUTTON_CONTINUE,
            cb = OnContinue
        }}
    ))
end

local function ClearWorldCallbacks(world)
    world:RemoveEventCallback("playeractivated", OnPlayerEnteredGame)
    world:RemoveEventCallback("entercharacterselect", OnPlayerEnteredGame)
end

OnPlayerEnteredGame = function(world)
    -- So we do not display this multiple times per one instance.
    ClearWorldCallbacks(world)

    if PEARL.AgreementManager:IsIntroPopupEnabled() and not PEARL.AgreementManager:AgreementDisplayed() then
        return ShowWelcomeScreen()
    end

    return OnContinue()
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
