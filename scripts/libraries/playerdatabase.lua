--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



------------------------------------------
-- [[ Localization ]]
------------------------------------------

local TheSim = TheSim
local json = json
local TrackedAssert = TrackedAssert

------------------------------------------
-- [[ Constants ]]
------------------------------------------

local DATABASE_FILE_PATH = PEARL.CONFIG.DATABASE.FOLDER.."/%s"

------------------------------------------
-- [[ Local Functions ]]
------------------------------------------

local function IsClearValue(value)
    return value == nil or value == ""
end

------------------------------------------
-- [[ Class Declaration ]]
------------------------------------------

--- @class PlayerDB
local PlayerDB = {
    _records = {},
}

------------------------------------------
-- [[ Getters ]]
------------------------------------------

function PlayerDB:HasRecord(userid)
    return io.exists(DATABASE_FILE_PATH:format(userid))
end

function PlayerDB:GetRecordFor(userid)
    return self._records[userid] or self:LoadRecordFor(userid)
end

function PlayerDB:GetField(userid, name)
    local record = self:GetRecordFor(userid)
    if not record then
        return
    end

    return record[name]
end

------------------------------------------
-- [[ Setters ]]
------------------------------------------

function PlayerDB:AddRecord(userid, record)
    self._records[userid] = record

    return record
end

function PlayerDB:AddPlayer(userid)
    if self:HasRecord(userid) then
        PEARL.error("Player already in db!")
    end

    return self:AddRecord(userid, self:CreateRecord())
end

--- We cannot delete files from this limited environment.
function PlayerDB:UnloadRecord(userid)
    local record = self._records[userid]
    self._records[userid] = nil

    return record
end

function PlayerDB:OptionalSetField(userid, name, value)
    local record = PEARL.PlayerDB:GetRecordFor(userid)
    if not record then
        return
    end

    local prev = record[name]
    record[name] = value

    return prev
end

function PlayerDB:OptionalSafeSetField(userid, name, value)
    if not IsClearValue(value) then
        return self:OptionalSetField(userid, name, value)
    end
end

------------------------------------------
-- [[ Public Methods ]]
------------------------------------------

--- Returns the record and a boolean determining whether the record was created or not.
function PlayerDB:EnsureRecordFor(userid)
    local record = self:GetRecordFor(userid)
    if not record then
        return self:AddPlayer(userid), true
    end

    return record, false
end

function PlayerDB:UpdateRecordFor(userid)
    return self:GetRecordFor(userid) or self:AddPlayer(userid)
end

function PlayerDB:CreateRecord()
    return {
        rep = 0,
        maxgriefness = 0,
        joinedtime = os.time(),
        totaldays = 0,
        gamerep = 0,
        profilerep = 0,
    }
end

function PlayerDB:LoadRecordFor(userid)
    local path = DATABASE_FILE_PATH:format(userid)
    io.ensure(path)

    local rf, err = io.open(path, "r")
    if not rf or err then
        PEARL.error(err)
        return
    end

    local str = rf:read("*a")
    rf:close()

    -- Decoding and un-encoded string should return nil
    local decoded = TheSim:DecodeAndUnzipString(str)
    str = decoded and #decoded > 0 and decoded or str

    local success, record = pcall(json.decode, str)
    record = record or {}

    if not success or type(record) ~= "table" then
        return
    end

    self._records[userid] = record

    return record
end

function PlayerDB:SaveRecordFor(userid, record)
    record = record or self._records[userid]
    if not record then
        return
    end

    local str = json.encode(record)
    if PEARL.CONFIG.DATABASE.ENCODE_DATA then
        -- Only encode and zip the data in production
        str = TheSim:ZipAndEncodeString(str)
    end

    if type(str) ~= "string" then
        return false
    end

    local wf, err = io.open(DATABASE_FILE_PATH:format(userid), "w")
    if not wf or err then
        return false, err
    end

    wf:write(str)
    wf:close()
end

function PlayerDB:SaveActiveRecords()
    for userid, record in pairs(self._records) do
        self:SaveRecordFor(userid, record)
    end
end

function PlayerDB:PrintDebugInfo()
    tdump(self._records)
end

------------------------------------------
-- [[ Return ]]
------------------------------------------

return PlayerDB
