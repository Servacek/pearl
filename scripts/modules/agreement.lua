--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @Category FrontEnd


--[[

--]]

--- @TODO: Check out also 'kleifileexists' as a possible alternative
-- We have already agreed to the agreement and the version of the agreement is the same as
-- the version of the newest released agreement.
local _agr_file_exists = io.exists(PEARL.CONSTS.AGREEMENT_FILE_PATH)
local _agr_file_version = io.line(PEARL.CONSTS.AGREEMENT_FILE_PATH)
if _agr_file_exists and _agr_file_version == PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT.version then
    return
end

local AgreementScreen = PEARL.loadfile("screens/agreementscreen")
local PopupDialogScreen = require("screens/redux/popupdialog")

--------------------------------------
-- [[ Locals ]]
--------------------------------------

local _agreement_displayed = false

local function OnPlayerFinishedAgreement(self, agreed)
    self:Close()

    if not agreed then
        return DoRestart(true)
    end

    local agr_file = io.open(PEARL.CONSTS.AGREEMENT_FILE_PATH, "w")
    if not agr_file then
        return PEARL.error("Failed to create the agreement cache file!")
    end

    if PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT.version ~= nil then
        agr_file:write(PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT.version)
    end
    agr_file:close()
end

local function ShowAgreement()
    local agreement_screen = AgreementScreen()
    agreement_screen:SetOnContinue(OnPlayerFinishedAgreement)

    TheFrontEnd:PushScreen(agreement_screen)
end

local function OnPlayerEnteredGame()
    if _agreement_displayed then
        return
    end

    -- We have already accepted the agreement but it was updated
    if _agr_file_exists then
        ShowAgreement()
    else -- We are on the server for the first time.
        TheFrontEnd:PushScreen(PopupDialogScreen(PEARL.CONFIG.WELCOME_POPUP_CONTENT[1].title, PEARL.CONFIG.WELCOME_POPUP_CONTENT[1].description, {
            {text = STRINGS.PEARL.UI.INTRO_POPUP_BUTTON_CONTINUE, cb = function()
                TheFrontEnd:PopScreen()

                ShowAgreement()
            end}
        }))
    end

    -- We should not get here if the agreement was not accepted
    _agreement_displayed = true
end

PEARL.AddWorldPostInit(function(world)
    world:ListenForEvent("playeractivated", OnPlayerEnteredGame)

    -- This is an lobby alternative for playeractivated
    world:ListenForEvent("entercharacterselect", OnPlayerEnteredGame)
end)
