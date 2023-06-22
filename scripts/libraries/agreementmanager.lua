--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--------------------------------
-- [[ Constants ]]
--------------------------------

--- 1.2.3;KU_ZC2919302;100203103020
local SEP = ";"
local REPL = ","
local FILE_HEADER_PATTERN = "%s"..SEP.."%s"..SEP.."%s\n"
local DECODE_PATTERN = "(.-)"..SEP

local RECORD = {
    VERSION = 1,
    USERID = 2,
    NETID = 3,

    MIN_SIZE = 2,
}

--------------------------------
-- [[ Local Functions ]]
--------------------------------

local function normalize(s)
    return s and s:strip():gsub(SEP, REPL) or ""
end

local function decodeline(line)
    line = line and line..SEP or "" -- Add the separator for the pattern to work properly.
    local fields = {}

    if #line > 1 then
        line:gsub(DECODE_PATTERN, function(match)
            fields[#fields+1] = normalize(match)
        end)
    end

    return fields
end

--------------------------------
-- [[ Class Declaration ]]
--------------------------------

--- @class AgreementManager
local AgreementManager = {
    records = {}
}

--------------------------------
-- [[ Static ]]
--------------------------------

AgreementManager.RECORD = RECORD

--------------------------------
-- [[ Getters ]]
--------------------------------

--- @return boolean exists Whether the agreement file exists on the disk or not.
function AgreementManager:FileExists()
    return io.exists(PEARL.CONSTS.AGREEMENT_FILE_PATH)
end

-- Support for older version of the agreement screen.
function AgreementManager:HasAnyRecords()
    return #self.records > 0 and self.records[1] and #self.records[1] >= RECORD.MIN_SIZE
end

function AgreementManager:AgreementDisplayed()
    -- We create an record only when the agreement is accepted for the first time.
    return self:HasRecord()
end

--- @return string globalversion Always a string, empty for no version specified.
function AgreementManager:GetGlobalVersion()
    return PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT and PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT.version or ""
end

--- @return string? localversion Nil when the record doesn't exist.
function AgreementManager:GetLocalVersion()
    local userid = TheNet:GetUserID()
    local record = self:GetRecord(userid, TheNet:GetNetIdForUser(userid))
    return record and record[RECORD.VERSION] or nil
end

--- @return boolean uptodate Whether the file exists and it version matches with the server's (global) version.
function AgreementManager:IsUpToDate()
    return self:FileExists() and normalize(self:GetGlobalVersion()) == normalize(self:GetLocalVersion())
end

--- @return boolean enabled Whether the agreement screen was configured by the server.
function AgreementManager:IsAgreementScreenEnabled()
    return type(PEARL.CONFIG.AGREEMENT_SCREEN_CONTENT) == "table"
end

--- @return boolean enabled Whether the welcome popup was configured on the server.
function AgreementManager:IsIntroPopupEnabled()
    return type(PEARL.CONFIG.WELCOME_POPUP_CONTENT) == "table"
end

--- @return boolean enabled Whether at least one of the introduction components is enabled.
function AgreementManager:IsEnabled()
    return self:IsAgreementScreenEnabled() or self:IsIntroPopupEnabled()
end

function AgreementManager:GetRecord(userid, netid)
    for _, record in ipairs(self.records) do
        -- Both needs to be equal to the saved version
        if record[RECORD.USERID] == userid and record[RECORD.NETID] == netid then
            return record
        end
    end
end

--- @return boolean exists Whether the record exists for the given id or not.
function AgreementManager:HasRecord()
    local userid = TheNet:GetUserID()
    return self:GetRecord(
        userid, TheNet:GetNetIdForUser(userid)
    ) ~= nil
end

function AgreementManager:CreateRecord(tbl)
    local record = tbl or {}
    table.insert(self.records, record)

    return record
end

--------------------------------
-- [[ Setters ]]
--------------------------------

function AgreementManager:UpdateRecord()
    local userid = TheNet:GetUserID()
    local netid = TheNet:GetNetIdForUser(userid)
    local record = self:GetRecord(userid, netid) or self:CreateRecord()

    -- This data here will be only used for verifying the client and version of the agreement.
    record[RECORD.VERSION] = normalize(self:GetGlobalVersion()) or ""
    record[RECORD.USERID] = userid or ""
    record[RECORD.NETID] = netid or ""

    return record
end

--------------------------------
-- [[ Public ]]
--------------------------------

function AgreementManager:Load()
    local rf, err = io.open(PEARL.CONSTS.AGREEMENT_FILE_PATH, "r")
    if not rf then
        -- It's ok to not a have an agreement file
        return PEARL.debug("Failed to load the agremeent file!", err)
    end

    for line in rf:lines() do
        local record = decodeline(line)
        if type(record) == "table" and #record >= #RECORD then
            table.insert(self.records, record)
        end
    end

    rf:close()
end

function AgreementManager:Save()
    local wf, err = io.open(PEARL.CONSTS.AGREEMENT_FILE_PATH, "w")
    if not wf then
        return PEARL.error("Failed to create the agreement cache file!", err)
    end

    wf:write(self:BuildFileHeader())
    wf:close()
end

function AgreementManager:BuildFileHeader()
    -- We need to save here the following:
    -- - version
    -- - userid
    -- - steamid

    local header = ""
    for _, record in ipairs(self.records) do
        if #record >= RECORD.MIN_SIZE then
            header = header..FILE_HEADER_PATTERN:format(unpack(record))
        end
    end

    return header
end

function AgreementManager:UpdateFile()
    self:UpdateRecord()
    self:Save()
end

--------------------------------
-- [[ Return ]]
--------------------------------

return AgreementManager
