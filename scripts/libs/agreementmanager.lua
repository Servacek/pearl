--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- Singleton class for managing the agreement file and it's data.


--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @singleton
--- @class AgreementManager
local AgreementManager = {}

--------------------------------
-- [[ Getters ]]
--------------------------------

--- @return boolean displayed
function AgreementManager:WasAgreementDisplayed()
    return PEARL.STORAGE.DATA.agreement and PEARL.STORAGE.DATA.agreement.displayed == true or false
end

--- @return boolean displayed
function AgreementManager:WasWelcomePopupDisplayed()
    return PEARL.STORAGE.DATA.welcome_dialog and PEARL.STORAGE.DATA.welcome_dialog.displayed == true or false
end

--- @return string globalversion Always a string, empty for no version specified.
function AgreementManager:GetGlobalVersion()
    local version = table.empty(PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT) == false and PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT.version or ""
    return tostring(version)
end

--- @return string? localversion Nil when the record doesn't exist.
function AgreementManager:GetLocalVersion()
    return PEARL.STORAGE.DATA.agreement and PEARL.STORAGE.DATA.agreement.version
end

--- @return number?
function AgreementManager:GetLocalLastAgreeTime()
    return tonumber(PEARL.STORAGE.DATA.agreement and PEARL.STORAGE.DATA.agreement.timeagreed or nil)
end

--- @return boolean uptodate Whether the version matches with the server's (global) version.
function AgreementManager:IsUpToDate()
    return self:GetGlobalVersion() == self:GetLocalVersion()
end

--- @return boolean enabled Whether the agreement screen was configured by the server.
function AgreementManager:IsAgreementScreenEnabled()
    return table.empty(PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT) == false
end

--- @return boolean enabled Whether the welcome popup was configured on the server.
function AgreementManager:IsWelcomePopupEnabled()
    return table.empty(PEARL.CONFIG.WELCOME_POPUP_CONTENT) == false
end

--- @return boolean enabled Whether at least one of the introduction components is enabled.
function AgreementManager:IsEnabled()
    return self:IsAgreementScreenEnabled() or self:IsWelcomePopupEnabled()
end

--- @return table
function AgreementManager:GetAgreementData()
    return PEARL.STORAGE.DATA.agreement
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

function AgreementManager:AgreementAutoDisplayed()
    PEARL.STORAGE.DATA.agreement = PEARL.STORAGE.DATA.agreement or {}
    PEARL.STORAGE.DATA.agreement.displayed = true
    PEARL.STORAGE.DATA.agreement.timedisplayed = tostring(os.time())

    PEARL.STORAGE.Save()
end

--- TODO: Handle player not agreeing to the agreement.
function AgreementManager:AgreementFinished(data)
    PEARL.STORAGE.DATA.agreement = PEARL.STORAGE.DATA.agreement or {}
    PEARL.STORAGE.DATA.agreement.version = self:GetGlobalVersion() or ""
    PEARL.STORAGE.DATA.agreement.timeagreed = tostring(os.time())
    PEARL.STORAGE.DATA.agreement.data = data

    PEARL.STORAGE.Save()
end

function AgreementManager:SyncAgreementDataWithServer()
    PEARL.SendRPCToServer(
        PEARL.RPC.AgreementDataReceived, ZipAndEncodeSaveData(self:GetAgreementData())
    )
end

--------------------------------
-- [[ Return ]]
--------------------------------

return AgreementManager
