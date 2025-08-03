--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--- Save lastactive shard for synchrnous reading between shards.
--- For other non-active shards, use RPCs to send the data to the active one.

local Library = PEARL.loadfile("models/library")

local MARKDOWN = PEARL.loadfile("libraries/markdown")

local Record = PEARL.loadfile("libraries/database/models/record")

------------------------------------------
-- [[ Constants ]]
------------------------------------------

local FILE_EXTENSION = ".json"
local FILE_PATH = "/%s"..FILE_EXTENSION
local ROOT = PEARL.ModPersistance:GetRootDirectoryPath()
local DATABASE_ROOT_PATH = ROOT.."/"..PEARL.CONFIG.DATABASE.DIRECTORIES.ROOT
local DATABASE_RECORD_PATH = DATABASE_ROOT_PATH.."/"..PEARL.CONFIG.DATABASE.DIRECTORIES.RECORDS..FILE_PATH

------------------------------------------
-- [[ Local Functions ]]
------------------------------------------

local function IsClearValue(value)
    return value == nil or value == ""
end

------------------------------------------
-- [[ Class Declaration ]]
------------------------------------------

--- @singleton
--- @class DB: Library
local DB = {
    --- @type table<string, PlayerRecord>
    _records = {},
}

--- @type DB
DB = Library(DB)

------------------------------------------
-- [[ Getters ]]
------------------------------------------

-- Currently we determine this by checking if "lastseentime" is nil,
-- since lastseentime is asigned after the first leave.
function DB:FirstTimeJoined(userid)
    local record = self:GetRecordFor(userid)
    return record and (record.lastseentime == nil or (
        (record.joinedtime == nil or record.joinedtime >= os.time() - 10) or
        (record.joinedtime == record.lastseentime)
    )) or false
end

--- @TODO: add these to some separate lib
function DB:MentionOrName(userid)
    local discordid = self:GetField(userid, "discordid")
    if discordid ~= nil then
        return MARKDOWN.mention(discordid, MARKDOWN.MENTION_TYPE.USER)
    end

    return self:GetField(userid, "username", userid)
end

--- The total number of records saved in this database.
--- @return integer
function DB:GetTotalRecordCount()
    return PEARL.AccountBindings:CountBindingsForType(PEARL.AccountBindings.BINDING_TYPE.STEAM)
end

--- @param userid string
--- @return string
function DB:GetRecordFilePathFor(userid)
    return DATABASE_RECORD_PATH:format(tostring(userid))
end

--- @return integer?
function DB:GetRecordLastUpdateTimeFor(userid)
    return io.fmtime(DB:GetRecordFilePathFor(userid))
end

--- Checks whether the provided userid has a record file created.
--- @param userid string The Klei ID of the user you want the record from.
--- @return boolean
function DB:HasRecordFile(userid)
    return userid and io.empty(self:GetRecordFilePathFor(userid)) == false
end

--- Supports Steam ID as well as Klei ID.
--- @param userid string The Klei ID of the user you want the record from.
--- @return PlayerRecord?
function DB:GetRecordFor(userid)
    if self:IsDisabled() then
        return PEARL.debug("Database disabled!")
    end

    if self._records[userid] ~= nil then
        return self._records[userid]
    end

    if not self:HasRecordFile(userid) then
        return -- The file is not created yet (this is quite common)
    end

    local record = self:LoadRecordFor(userid, true)
    -- If the record is not active on this shard but somewhere else.
    if record and record:IsReadOnly() then
        -- If not on active shard, unload the record the next tick
        -- to ensure the data stays up-to-date.
        PEARL.WallScheduler:ExecuteInTime(0, function()
            self:UnloadRecord(userid)
        end)
    end

    return record
end

--- @param userid string
--- @param name string
--- @param default? any?
--- @return any?
function DB:GetField(userid, name, default)
    local record = self:GetRecordFor(userid)
    if record == nil or record[name] == nil then
        if default ~= nil then
            return default
        end

        return Record.GetDefaultForField(name, userid)
    end

    return record[name]
end

function DB:IsRecordCachedFor(userid)
    return type(self._records[userid]) == "table"
end

------------------------------------------
-- [[ Setters ]]
------------------------------------------

--- @param userid string
--- @param record PlayerRecord
--- @return PlayerRecord?
function DB:CacheRecord(userid, record)
    PEARL.debug("CacheRecord", userid, record)

    if self:IsRecordCachedFor(userid) then
        return PEARL.error("Player already cached!")
    end

    self._records[userid] = record

    return record
end

--- We cannot delete files from this limited environment.
--- Used to free the memory of record after the player leaves.
--- @param userid string
--- @return PlayerRecord?
function DB:UnloadRecord(userid)
    PEARL.debug("DB:UnloadRecord", userid)

    local record = self._records[userid]
    self._records[userid] = nil

    return record
end

--- @param userid string
--- @param name string Name of the field in the database.
--- @param value any|nil
--- @return boolean success, any? previous
function DB:SetField(userid, name, value)
    local record = self:GetRecordFor(userid)
    if not record then
        return false -- optional
    end

    if record:IsReadOnly() then
        PEARL.error("Attempted to set a field for a read-only record! The record is loaded in r-w mode on shard", record.lastshardid, CalledFrom())
        return false
    end

    local prev = record[name]
    if prev == value and type(value) ~= "table" then
        return true, prev -- No changes
    end

    if prev ~= nil and value ~= nil and type(prev) ~= type(value) then
        PEARL.error("Type conversions not allowed for DB record!", prev, value, "from", type(prev), "to", type(value))

        return false
    end

    record[name] = value

    return true, prev
end

--- @param userid string
--- @param name string
--- @param value any
--- @return boolean success, any? previous
function DB:SafeSetField(userid, name, value)
    if not IsClearValue(value) then
        return self:SetField(userid, name, value)
    end

    return false, nil
end

------------------------------------------
-- [[ Public Methods ]]
------------------------------------------

--- Returns the record and a boolean determining whether the record was created or not.
--- @param userid string
--- @param netid string?
--- @return PlayerRecord? record
function DB:CreateRecordFor(userid, netid)
    if not PEARL.IsKleiIDValid(userid) then
        return PEARL.error("Invalid Klei ID provided!")
    end

    if self:HasRecordFile(userid) then
        return PEARL.error("Record file for", userid, "already exists...")
    end

    local cached_record = self:GetRecordFor(userid)
    if cached_record then
        PEARL.error("Record cached but no valid file exists! Creating one...")
        self:SaveRecordFor(userid, cached_record)
        return
    end

    PEARL.info("Creating database record for", userid)

    local record = Record.New(userid)
    if type(record) ~= "table" then
        return PEARL.error("Failed to create record for", userid)
    end

    -- Make sure the file exists
    -- And the initial data are always recorded.
    self:CacheRecord(userid, record)
    self:SaveRecordFor(userid, record)

    -- Apply default bindings
    netid = netid or TheNet:GetNetIdForUser(userid)
    if not netid then
        PEARL.error("Failed to retrive Steam ID for ", userid)
    else
        -- This should ALWAYS be string but just in case it's not...
        PEARL.AccountBindings:AddBinding(userid, tostring(netid), PEARL.AccountBindings.BINDING_TYPE.STEAM)
    end

    PEARL.EventProcessor:HandleEvent("db_recordcreated", userid, record)

    return record
end

--- WARNING: This function doesn't cache the record!
--- Loads the record data from the actual database file for the given player.
--- @param userid string
--- @param validate boolean?
--- @return table? record
function DB:LoadRecordFor(userid, validate, record)
    if not PEARL.IsKleiIDValid(userid) then
        return PEARL.error("Invalid Klei ID provided!")
    end

    PEARL.info("Loading record for ", userid)
    local data = PEARL.ModPersistance:LoadDataFromFile(self:GetRecordFilePathFor(userid))
    if type(data) ~= "table" then
        PEARL.error("Failed to load record for", userid)
        return
    end

    record = record and record:Init(userid, data) or Record(userid, data)
    if validate == true then
        record:Validate(userid)
    end

    -- Only cache when we are the active shard.
    self:CacheRecord(userid, record)

    -- Called right after the record is loaded so the fresh data can be modified.
    PEARL.EventProcessor:HandleEvent("db_recordloaded", userid, record)

    return record
end

--- Save the database record data for the given player.
--- @param userid string
--- @param record PlayerRecord?
--- @return boolean success
function DB:SaveRecordFor(userid, record)
    PEARL.debug("DB:SaveRecordFor", userid)

    if not PEARL.IsKleiIDValid(userid) then
        PEARL.error("Invalid Klei ID provided!", PEARL.CalledFrom(4))
        return false
    end

    record = record or self._records[userid]
    if not record then
        PEARL.error("Record for", userid, "is not cached.")
        return false
    end

    if record:IsReadOnly() then
        PEARL.debug("Ignoring DB:SaveRecordFor call because the record", userid, "is read-only!")
        return false
    end

    if record:IsUpToDate() then
        PEARL.debug("Not saving the record file because no changes were done!")
        return true -- We pretended that it succeeded since the effect is the same.
    end

    -- Called before the actual saving so we have time to change some of the data.
    PEARL.EventProcessor:HandleEvent("db_savingrecord", userid)

    --- We have to set this before the actual saving.
    --- Make sure we handle the case where saving fails.
    local lastupdate = record.lastupdate
    record.lastupdate = os.time()

    if PEARL.ModPersistance:SaveDataToFile(
        self:GetRecordFilePathFor(userid), record:GetData(), true
    ) then
        record:SetIsUpToDate(true)
        return true
    end

    record.lastupdate = lastupdate

    PEARL.error("Failed to save record for", userid)
    return false
end

function DB:SaveUnsavedRecords()
    if DB:IsDisabled() then
        return PEARL.debug("Database disabled!")
    end

    PEARL.info("Saving the database...")

    for userid, record in pairs(DB._records) do
        DB:SaveRecordFor(userid, record)

        if not record:IsActive() then
            -- Free up the memory since the client is no longer activelly writing to the record.
            DB:UnloadRecord(userid)
        end
    end
end

------------------------------------------
-- [[ Debugging ]]
------------------------------------------

function DB:PrintDebugInfo()
    table.dump(self._records)
end

------------------------------------------
-- [[ Event Handlers ]]
------------------------------------------

local function OnSave()
    return DB:SaveUnsavedRecords()
end

------------------------------------------
-- [[ Event Listeners ]]
------------------------------------------

PEARL.EventProcessor:AddSafeEventHandler("save", OnSave)
PEARL.EventProcessor:AddSafeEventHandler("quit", OnSave)

------------------------------------------
-- [[ Return ]]
------------------------------------------

return DB
