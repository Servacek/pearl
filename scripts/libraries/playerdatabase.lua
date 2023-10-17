--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--[[
    @TODOS:
        - Make database records shard specific (they would be unloaded upon migration despawn)
        - Rethink the data collection dilema.
        - Maybe we save the lastinv as well?
]]


------------------------------------------
-- [[ Localization ]]
------------------------------------------

local TheSim = TheSim
local json = json

------------------------------------------
-- [[ Constants ]]
------------------------------------------

local DATABASE_FILE_PATH = PEARL.CONFIG.DATABASE.FOLDER.."/%s"
local DATABASE_LISTING_FILE_PATH = PEARL.CONFIG.DATABASE.FOLDER.."/userids"

local STARTING_REPUTATION = PEARL.CONSTS.STARTING_REPUTATION

local RECORD_TEMPLATE = {
    joinedtime = nil,
    totaldays = 0,
    netid = nil,
    reputation = {
        value = STARTING_REPUTATION,
        peak = STARTING_REPUTATION,
        lowest = STARTING_REPUTATION,
        monthgains = 0,
        daygains = 0,
    },
    agreement = {
        collectdata = false,
    },
}

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
    -- Here we will safe all active (cached) records.
    _records = {},
    _userids = {},

    _enabled = true,
}

------------------------------------------
-- [[ Getters ]]
------------------------------------------

-- Currently we determine this by checking if "lastseentime" is nil,
-- since lastseentime is asigned after the first leave.
function PlayerDB:FirstTimeJoined(userid)
    local record = self:GetRecordFor(userid)
    return record and record.lastseentime == nil
end

--- @return boolean
function PlayerDB:IsDataCollectionEnabledFor(userid)
    local record = self:GetRecordFor(userid)
    return record and record.agreement and record.agreement.collectdata == true or false
end

--- The total number of records saved in this database.
--- @return number
function PlayerDB:GetTotalRecordCount()
    return self._userids.count or 0
end

--- Checks whether the provided userid has a record file created.
--- @param userid string The Klei ID of the user you want the record from.
--- @return boolean
function PlayerDB:HasRecord(userid)
    return io.exists(DATABASE_FILE_PATH:format(userid))
end

--- Supports Steam ID as well as Klei ID.
--- @param userid string The Klei ID of the user you want the record from.
--- @return table<string, any>? record The record of the provided player.
function PlayerDB:GetRecordFor(userid)
    print(PEARL.CalledFrom(5))
    if self:IsDisabled() then
        return
    end

    userid = self:MapNetID(userid) or userid

    return self._records[userid] or self:LoadRecordFor(userid)
end

function PlayerDB:GetField(userid, name, default)
    local record = self:GetRecordFor(userid)
    if not record or record[name] == nil then
        if default == nil then
            return RECORD_TEMPLATE[name]
        end

        return default
    end

    return record[name]
end

function PlayerDB:GetSubField(userid, field, name, default)
    local tbl = self:GetField(userid, field)
    if not tbl or tbl[name] == nil then
        return default or RECORD_TEMPLATE[field] and RECORD_TEMPLATE[field][name]
    end

    return tbl[name]
end

function PlayerDB:IsRecordLoadedFor(userid)
    return type(self._records[userid]) == "table"
end

function PlayerDB:IsEnabled()
    return self._enabled == true
end

function PlayerDB:IsDisabled()
    return self._enabled ~= true
end

function PlayerDB:MapNetID(netid)
    return self._userids[netid]
end

------------------------------------------
-- [[ Setters ]]
------------------------------------------

-- Userids are mapped by Steam IDs for easier access.
-- We store the whole list of IDs so we can traverse all records if needed,
-- since we cannot list files.
function PlayerDB:AddUserid(userid, netid)
    if self:IsDisabled() then
        return
    end

    if not self._userids[netid] then
        self._userids[netid] = userid
        self._userids.count = (self._userids.count or 0) + 1
    end
end

--- @return table<string, any>?
function PlayerDB:CacheRecord(userid, record)
    PEARL.debug("CacheRecord", userid, record)

    if type(userid) ~= "string" or #userid ~= 11 then
        return PEARL.error("Invalid Klei ID provided!")
    end

    if self:IsRecordLoadedFor(userid) then
        return PEARL.error("Player already cached!")
    end

    self._records[userid] = record

    return record
end

--- We cannot delete files from this limited environment.
--- Used to free the memory of record after the player leaves.
--- @return table<string, any>?
function PlayerDB:UnloadRecord(userid)
    local record = self._records[userid]
    self._records[userid] = nil

    return record
end

function PlayerDB:OptionalSetField(userid, name, value)
    local record = PEARL.PlayerDB:GetRecordFor(userid)
    if not record then
        return false -- optional
    end

    local prev = record[name]
    if prev ~= nil and value ~= nil and type(prev) ~= type(value) then
        return PEARL.error("Type conversions not allowed for DB record!", prev, value, "from", type(prev), "to", type(value))
    end

    record[name] = value

    return true, prev
end

function PlayerDB:OptionalSafeSetField(userid, name, value)
    if not IsClearValue(value) then
        return self:OptionalSetField(userid, name, value)
    end

    return false
end

function PlayerDB:SetIsEnabled(enabled)
    self._enabled = enabled
end

------------------------------------------
-- [[ Public Methods ]]
------------------------------------------

--- Returns the record and a boolean determining whether the record was created or not.
--- This doesn't save the newly created record.
function PlayerDB:EnsureRecordFor(userid)
    if type(userid) ~= "string" or #userid ~= 11 then
        return PEARL.error("Invalid Klei ID provided!", PEARL.CalledFrom(5))
    end

    local record = self:GetRecordFor(userid)
    if not record then
        PEARL.debug("Creating database record for", userid)

        record = self:CacheRecord(userid, self:CreateRecordFor(userid))
        if type(record) ~= "table" then
            return PEARL.error("Failed to create record for", userid)
        end

        -- Netid should never be nil
        self:AddUserid(userid, record.netid)

        -- Make sure the file exists
        -- And the initial data are always recorded.
        self:SaveRecordFor(userid, record, true)

        -- Also save the userid list here, because this is the only place
        -- where we are modifying it in some way.
        -- We want to make sure that the info there is always up-to-date
        -- with the record files created in case of some unexcpected shutdowns or crashes.
        self:SaveUseridList()

        return record, true
    end

    return record, false
end

-- Put stuff that's available from the start and doesn't change here.
function PlayerDB:CreateRecordFor(userid)
    local record = deepcopy(RECORD_TEMPLATE)
    record.joinedtime = os.time()
    record.userid = userid

    local netid = TheNet:GetNetIdForUser(userid)
    if not netid then
        PEARL.error("Failed to retrive Steam ID for ", userid)
    end

    -- This should ALWAYS be string but just in case it's not...
    record.netid = netid and tostring(netid)

    return record
end

function PlayerDB:SaveToDatabaseFile(path, data, ensure, encode)
    if ensure then
        io.ensure(path, "{}")
    end

    encode = encode ~= nil and encode
    if not encode then
        encode = PEARL.CONFIG.DATABASE.ENCODE_DATA
    end

    local data_str = json.encode(data)
    if encode then
        -- Only encode and zip the data in production
        data_str = TheSim:ZipAndEncodeString(data_str)
    end

    if type(data_str) ~= "string" then
        return false
    end

    local wf, err = io.open(path, "w")
    if not wf or err then
        return false, err
    end

    wf:write(data_str)
    return wf:close()
end

--- @return table?
function PlayerDB:LoadDatabaseFile(path, ensure)
    if ensure then
        io.ensure(path, "{}")
    end

    -- Klei has some weird checks here when opening files with special characters in path.
    -- This throws an error when the path cotains a ':' for example.
    local rf, err = io.open(path, "r")
    if not rf or err then
        PEARL.error(err or rf)
        return
    end

    local str = rf:read("*a")
    rf:close()

    -- Decoding and un-encoded string should return nil
    local decoded = TheSim:DecodeAndUnzipString(str)
    str = decoded and #decoded > 0 and decoded or str

    local success, data = pcall(json.decode, str)
    if not success or type(data) ~= "table" then
        return
    end

    return data
end

function PlayerDB:LoadUseridList()
    self._userids = self:LoadDatabaseFile(DATABASE_LISTING_FILE_PATH, true) or self._userids
    return self._userids
end

function PlayerDB:SaveUseridList()
    return self:SaveToDatabaseFile(DATABASE_LISTING_FILE_PATH, self._userids, true)
end

function PlayerDB:LoadRecordFor(userid)
    PEARL.debug("LoadRecordFor", userid)

    self._records[userid] = self:LoadDatabaseFile(DATABASE_FILE_PATH:format(userid))
    return self._records[userid]
end

function PlayerDB:SaveRecordFor(userid, record, force)
    PEARL.debug("SaveRecordFor", userid, record, force)

    record = record or self._records[userid]
    -- Only save data for users that have agreed to the agreement.
    --- @TODO: Re-think the data collection complication.
    --- @TODO: Make the first agreement screen popup up before joining the server.
    if not record then --or (not self:IsDataCollectionEnabledFor(userid) and force ~= true) then
        return
    end

    return self:SaveToDatabaseFile(
        DATABASE_FILE_PATH:format(userid), record, true
    )
end

function PlayerDB:PrintDebugInfo()
    table.dump(self._records)
end

------------------------------------------
-- [[ Event Handlers ]]
------------------------------------------

local function OnSave()
    if PlayerDB:IsDisabled() then
        return
    end

    PEARL.info("Saving the database...")

    -- Save lastseentime, lastdays here as well, because we may be shutting down,
    -- or the server may crash during restarting/rollbacking
    local time_now = os.time()
    for userid, _ in pairs(PlayerDB._records) do
        if PEARL.ServerNetwork:IsUserConnected(userid) then
            PlayerDB:OptionalSafeSetField(userid, "lastseentime", time_now)
        end

        PlayerDB:SaveRecordFor(userid)
    end
end

------------------------------------------
-- [[ Event Listeners ]]
------------------------------------------

PEARL.EventProcessor:AddSafeEventHandler("save", OnSave)
PEARL.EventProcessor:AddSafeEventHandler("quit", OnSave)

------------------------------------------
-- [[ Return ]]
------------------------------------------

return PlayerDB
