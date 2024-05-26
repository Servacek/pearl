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
-- [[ Constants ]]
--------------------------------

--- FIELD NAME -> FIELD INDEX
--- @enum REQUIRED_FIELDS
local REQUIRED_FIELDS = {NETID = 1, USERID = 2}

--- FIELD NAME -> FIELD INDEX
--- @enum FIELDS
local FIELDS = {
    VERSION = 1, -- Version of the last agreed agreement.
    USERID  = 2, -- Klei ID of the account agreeing to the agreement.
    NETID   = 3, -- Steam ID of the account agreeing to the agreement.
    TIME    = 4, -- Last time the agreement was agreed to.
}

--- 1.2.3;KU_ZC2919302;100203103020;169200202003
local SEP = ";"
local REPL = ","
local DECODE_PATTERN = "(.-)"..SEP

--------------------------------
-- [[ Local Functions ]]
--------------------------------

local function normalize(s)
    return s and s:strip():gsub(SEP, REPL) or ""
end

local function decodeline(line)
    local fields = {}

    line = line:endswith(SEP) and line or line..SEP
    if not line:blank() then
        line:gsub(DECODE_PATTERN, function(match)
            fields[#fields+1] = normalize(match)
        end)
    end

    return fields
end

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @singleton
--- @class AgreementManager
local AgreementManager = {records = {}}

--------------------------------
-- [[ Static ]]
--------------------------------

--- @param record table<number, string>
--- @return boolean
function AgreementManager.IsRecordValid(record)
    if table.empty(record) ~= false then
        return false
    end

    for _, required_field in pairs(REQUIRED_FIELDS) do
        if not record[required_field] or type(record[required_field]) ~= "string" or record[required_field]:blank() then
            return false
        end
    end

    return true
end

--------------------------------
-- [[ Getters ]]
--------------------------------

--- @return boolean exists Whether the agreement file exists on the disk or not.
function AgreementManager:FileExists()
    return io.exists(PEARL.CONSTS.AGREEMENT_FILE_PATH) == true
end

--- @return boolean displayed
function AgreementManager:AgreementDisplayed()
    -- We create an record only when the agreement is accepted for the first time.
    return self:HasRecord()
end

--- @return string globalversion Always a string, empty for no version specified.
function AgreementManager:GetGlobalVersion()
    return table.empty(PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT) == false and PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT.version or ""
end

--- @param field FIELDS
--- @return string? record
function AgreementManager:GetLocalRecordField(field)
    local userid = TheNet:GetUserID()
    local record = self:GetRecord(userid, TheNet:GetNetIdForUser(userid))
    if record then
        return record[field]
    end
end

--- @return string? localversion Nil when the record doesn't exist.
function AgreementManager:GetLocalVersion()
    return self:GetLocalRecordField(self.RECORD.VERSION)
end

--- @return number?
function AgreementManager:GetLocalLastAgreeTime()
    return tonumber(self:GetLocalRecordField(self.RECORD.TIME) or nil)
end

--- @return boolean uptodate Whether the file exists and it version matches with the server's (global) version.
function AgreementManager:IsUpToDate()
    return self:FileExists() and normalize(self:GetGlobalVersion()) == normalize(self:GetLocalVersion())
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

--- One Steam account can play as multiple Klei accounts, therefore we need both IDs.
--- @param userid string
--- @param netid string
--- @return table<number, string>? record
function AgreementManager:GetRecord(userid, netid)
    for _, record in ipairs(self.records) do
        if record[FIELDS.USERID] == userid and record[FIELDS.NETID] == netid then
            return record
        end
    end
end

--- @return boolean exists Whether the record exists for the given id or not.
function AgreementManager:HasRecord()
    local userid = TheNet:GetUserID()
    return self:GetRecord(userid, TheNet:GetNetIdForUser(userid)) ~= nil
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

--- Creates the record if needed
function AgreementManager:UpdateRecord()
    local userid = TheNet:GetUserID()
    local netid = TheNet:GetNetIdForUser(userid)
    local record = self:GetRecord(userid, netid)
    if not record then
        record = {}
        table.insert(self.records, record)
    end

    -- This data here will be only used for verifying the client and version of the agreement.
    record[FIELDS.VERSION]  = normalize(self:GetGlobalVersion()) or ""
    record[FIELDS.USERID]   = tostring(userid or "")
    record[FIELDS.NETID]    = tostring(netid or "")
    record[FIELDS.TIME]     = tostring(os.time())

    if not AgreementManager.IsRecordValid(record) then
        PEARL.error("Record became invalid!", table.dump(record))
    end
end

function AgreementManager:Load()
    local lines = PEARL.ModPersistence:GetAllFileLines(PEARL.CONSTS.AGREEMENT_FILE_PATH, false, true)
    for line in ipairs(lines) do
        local record = decodeline(line)
        if AgreementManager.IsRecordValid(record) then
            table.insert(self.records, record)
        end
    end
end

function AgreementManager:Save()
    local success, err = PEARL.ModPersistence:SetFileContent(PEARL.CONSTS.AGREEMENT_FILE_PATH, self:BuildFileContent())
    if not success then
        PEARL.error("Failed to create the agreement cache file!", err)
    end
end

function AgreementManager:BuildFileContent()
    local content = ""
    for _, record in ipairs(self.records) do
        content = content..table.concat(record, SEP).."\n"
    end

    return content
end

function AgreementManager:UpdateFile()
    self:UpdateRecord()
    self:Save()
end

function AgreementManager:SyncAgreementDataWithServer(agreed, datacollection, agreedintime, version)
    PEARL.SendRPCToServer(
        PEARL.RPC.AgreementDataReceived, agreed, datacollection, agreedintime, version
    )
end

--------------------------------
-- [[ Return ]]
--------------------------------

return AgreementManager
