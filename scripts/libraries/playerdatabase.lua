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

local DATABASE_FILE_PATH = "_pdb"

------------------------------------------
-- [[ Class Declaration ]]
------------------------------------------

--- @class PlayerDB
local PlayerDB = {
    _records = {},
    _loaded = false,
}

------------------------------------------
-- [[ Getters ]]
------------------------------------------

function PlayerDB:HasRecord(userid)
    return table.empty(self._records[userid])
end

function PlayerDB:GetRecordFor(userid)
    return self._records[userid]
end

function PlayerDB:IsLoaded()
    return self._loaded
end

------------------------------------------
-- [[ Setters ]]
------------------------------------------

function PlayerDB:AddRecord(userid, record)
    self._records[userid] = record

    return record
end

function PlayerDB:AddPlayer(player)
    if self:HasRecord(player.userid) then
        PEARL.error("Player already in db!")
    end

    local record = self:CreateRecord()
    self:AddRecord(player.userid, record)
    self:UpdateRecordFor(player)

    return record
end

function PlayerDB:RemoveRecord(userid)
    local record = self._records[userid]
    self._records[userid] = nil

    return record
end

------------------------------------------
-- [[ Public Methods ]]
------------------------------------------

function PlayerDB:UpdateRecordFor(player)
    local record = self:GetRecordFor(player.userid)
    if record then
        record.lastprefab = player.prefab
        record.lasttime = player.lasttime

        return record
    end

    return self:AddPlayer(player)
end

function PlayerDB:CreateRecord()
    return {
        rep = 0,
        maxgriefness = 0,
    }
end

function PlayerDB:Load()
    io.ensure(DATABASE_FILE_PATH)

    local rf, err = io.open(DATABASE_FILE_PATH, "r")
    if not rf or err then
        return false, err
    end

    local str = rf:read("*a")
    rf:close()

    local decoded = TheSim:DecodeAndUnzipString(str)
    str = decoded and #decoded > 0 and decoded or str

    print(str)
    local success, records = RunInSandboxSafe(str)
    records = records or {}

    print(records)

    if not success or type(records) ~= "table" then
        return false
    end

    tdump(records)

    self._records = records
    self._loaded = true

    return true
end

function PlayerDB:Save()
    local str = DataDumper(self._records, nil, true)
    if not PEARL.CONFIG.DEBUG_MODE then
        -- Only encode and zip the data in production
        str = TheSim:ZipAndEncodeString(str)
    end

    if type(str) ~= "string" then
        return false
    end

    local wf, err = io.open(DATABASE_FILE_PATH, "w")
    if not wf or err then
        return false, err
    end

    wf:write(str)
    wf:close()
end

function PlayerDB:PrintDebugInfo()
    tdump(self._records)
end

------------------------------------------
-- [[ Return ]]
------------------------------------------

return PlayerDB
