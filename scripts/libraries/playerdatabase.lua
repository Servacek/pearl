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

--- @TODO: Save lastactive shard for synchrnous reading between shards.
--- For other non-active shards, use RPCs to send the data to the active one.

local Library = PEARL.loadfile("models/library")

------------------------------------------
-- [[ Localization ]]
------------------------------------------

local TheSim = TheSim
local json = json

------------------------------------------
-- [[ Constants ]]
------------------------------------------

local DATABASE_FILE_PATH = PEARL.CONFIG.DATABASE.FOLDER.."/%s"

local BINDING_TYPE = {
    STEAM = "steamids",
    DISCORD = "discordids",
}

local BINDING_FIELD = {
    -- Shortcut used by the game, we inherit it for consistency.
    [BINDING_TYPE.STEAM] = "netid"
}
for name, type in pairs(BINDING_TYPE) do
    if BINDING_FIELD[type] == nil then
        BINDING_FIELD[type] = string.lower(name).."id"
    end
end

--- Put default non-dynamic record data here.
local RECORD_TEMPLATE = {
    joinedtime = nil,
    totaldays = 0,
    netid = nil,
    agreement = {
        collectdata = false,
    },
}

------------------------------------------
-- [[ Local Functions ]]
------------------------------------------

-- local function CreateRecordMT(t)
--     return {
--         __saved     = deepcopy(t),
--         __changes   = 0,
--     }
-- end

local function IsClearValue(value)
    return value == nil or value == ""
end

------------------------------------------
-- [[ Class Declaration ]]
------------------------------------------

--- @singleton
--- @class DB: Library
local DB = {
    -- Here we will safe all active (cached) records.
    _records = {},

    _bindings = {
        [BINDING_TYPE.DISCORD]  = nil,
        [BINDING_TYPE.STEAM]    = nil,
    }
}

--- @type DB
DB = Library(DB)

------------------------------------------
-- [[ Static ]]
------------------------------------------

DB.BINDING_TYPE    = BINDING_TYPE
DB.BINDING_FIELD   = BINDING_FIELD

------------------------------------------
-- [[ Getters ]]
------------------------------------------

-- Currently we determine this by checking if "lastseentime" is nil,
-- since lastseentime is asigned after the first leave.
function DB:FirstTimeJoined(userid)
    local record = self:GetRecordFor(userid)
    return record and record.lastseentime == nil
end

--- @return boolean
function DB:IsDataCollectionEnabledFor(userid)
    --- @TODO:
    --local record = self:GetRecordFor(userid)
    --return record and record.agreement and record.agreement.collectdata == true or false
    return true
end

--- The total number of records saved in this database.
--- @return number
function DB:GetTotalRecordCount()
    return self._bindings and table.size(self._bindings[BINDING_TYPE.STEAM])
end

function DB:GetRecordFilePathFor(userid)
    return DATABASE_FILE_PATH:format(userid)
end

--- Checks whether the provided userid has a record file created.
--- @param userid string The Klei ID of the user you want the record from.
--- @return boolean
function DB:HasRecordFile(userid)
    return userid and io.exists(DATABASE_FILE_PATH:format(userid))
end

--- Supports Steam ID as well as Klei ID.
--- @param userid string The Klei ID of the user you want the record from.
--- @return table<string, any>? record The record of the provided player.
function DB:GetRecordFor(userid)
    if self:IsDisabled() then
        return
    end

    userid = self:MapSteamID(userid) or userid

    if self._records[userid] then
        return self._records[userid]
    end

    local record = self:LoadRecordFor(userid, true)
    if record then
        return self:CacheRecord(userid, record)
    end
end

--- @param userid string
--- @param name string
--- @param default? any?
--- @return any?
function DB:GetField(userid, name, default)
    local record = self:GetRecordFor(userid)
    if not record or record[name] == nil then
        if default == nil then
            return RECORD_TEMPLATE[name]
        end

        return default
    end

    return record[name]
end

function DB:GetSubField(userid, field, name, default)
    local tbl = self:GetField(userid, field)
    if not tbl or tbl[name] == nil then
        return default or RECORD_TEMPLATE[field] and RECORD_TEMPLATE[field][name]
    end

    return tbl[name]
end

function DB:IsRecordLoadedFor(userid)
    return type(self._records[userid]) == "table"
end

function DB:MapSteamID(steamid)
    return self._bindings[BINDING_TYPE.STEAM][steamid]
end

function DB:MapDiscordID(discordid)
    return self._bindings[BINDING_TYPE.DISCORD][discordid]
end

--- @param userid string
--- @param bindtype string
--- @return string? bindid
function DB:MapUserIDToType(userid, bindtype)
    if userid then
        return
    end

    local bindid = self:GetField(userid, BINDING_FIELD[bindtype])
    if bindid then
        return bindid
    end

    bindid = table.getkey(self._bindings[bindtype], userid)
    if bindid ~= nil then
        return tostring(bindid)
    end
end

function DB:BindingExists(userid, bindid, bindtype)
    return(
        -- The binding must exist in both files in order to be marked as existing.
        self._bindings[bindtype][bindid] == userid and self:GetField(userid, BINDING_FIELD[bindtype]) == bindid
    )
end

function DB:BindingExistsAny(userid, bindtype)
    return (
        table.contains(self._bindings[bindtype], userid)
    )
end

--- @param bindtype string
--- @return table? bindings
function DB:GetBindings(bindtype)
    return self._bindings[bindtype]
end

------------------------------------------
-- [[ Setters ]]
------------------------------------------

-- Userids are mapped by Steam IDs for easier access.
-- We store the whole list of IDs so we can traverse all records if needed,
-- since we cannot list files.
--- @param userid string
--- @param bindid string
--- @param bindtype string
function DB:AddBinding(userid, bindid, bindtype)
    if self:BindingExists(userid, bindid, bindtype) then
        return PEARL.error("Binding", bindid, "->", userid, "already exists!")
    end

    self._bindings[bindtype][bindid] = userid
    self:SetField(userid, BINDING_FIELD[bindtype], bindid)

    -- We have to save after every adding because there is no global saving for binding files.
    -- Also save the userid list here, because this is the only place
    -- where we are modifying it in some way.
    -- We want to make sure that the info there is always up-to-date
    -- with the record files created in case of some unexcpected shutdowns or crashes.
    self:SaveBindingFile(bindtype)

    PEARL.debug("Binding", bindid, "->", userid, "successfully added!")
end

--- @param userid string
--- @param bindid string
--- @param bindtype string
function DB:RemoveBinding(userid, bindid, bindtype)
    local bindings = self:GetBindings(bindtype)
    if not bindings then
        return PEARL.error("Invalid binding type provided!")
    end

    --- @TODO: Use PersistentMap instead? (Add change tracking to it)
    -- local current = bindings[bindid]
    -- local mt = getmetatable(bindings)
    -- if mt and mt.__saved and mt.__changes then
    --     if current ~= nil and mt.__saved == nil and mt.__changes > 0 then
    --         mt.__changes = mt.__changes - 1
    --     elseif mt.__saved ~= nil then

    --     end
    -- end
    -- Bidirectional binding, remove both references
    bindings[bindid] = nil
    self:SetField(userid, BINDING_FIELD[bindtype], nil)

    self:SaveBindingFile(bindtype)

    PEARL.debug("Binding", bindid, "->", userid, "successfully removed!")
end

--- @param userid string
--- @param record table<string, any>
--- @return table<string, any>?
function DB:CacheRecord(userid, record)
    PEARL.debug("CacheRecord", userid, record)

    if type(userid) ~= "string" or #userid ~= 11 then
        return PEARL.error("Invalid Klei ID provided!")
    end

    if self:IsRecordLoadedFor(userid) then
        return PEARL.error("Player already cached!")
    end

    self._records[userid] = record --setmetatable(record, CreateRecordMT(record))

    return record
end

--- We cannot delete files from this limited environment.
--- Used to free the memory of record after the player leaves.
--- @param userid string
--- @return table<string, any>?
function DB:UnloadRecord(userid)
    local record = self._records[userid]
    self._records[userid] = nil

    return record
end

--- @param userid string
--- @param name string Name of the field in the database.
--- @param value any|nil
--- @return boolean success, any? previous
function DB:SetField(userid, name, value)
    local record = PEARL.DB:GetRecordFor(userid)
    if not record then
        return false -- optional
    end

    local prev = record[name]
    if prev == value then
        return true
    end

    if prev ~= nil and value ~= nil and type(prev) ~= type(value) then
        PEARL.error("Type conversions not allowed for DB record!", prev, value, "from", type(prev), "to", type(value))

        return false
    end

    record[name] = value
    -- local mt = getmetatable(record)
    -- if mt and mt.__changes and mt.__saved then
    --     local saved = mt.__saved[name]
    --     if saved ~= prev and saved == value and mt.__changes > 0 then
    --         mt.__changes = mt.__changes - 1
    --     elseif saved == prev and saved ~= value then
    --         mt.__changes = mt.__changes + 1
    --     end
    -- end

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
--- This doesn't save the newly created record.
--- @param userid string
--- @return table<string, any>? record
function DB:CreateRecordFile(userid)
    PEARL.debug("Creating database record for", userid)

    local record = self:AllocateRecordTableFor(userid)
    if type(record) ~= "table" or not self:CacheRecord(userid, record) then
        return PEARL.error("Failed to create record for", userid)
    end

    -- Make sure the file exists
    -- And the initial data are always recorded.
    self:SaveRecordFor(userid, record)

    -- Apply default bindings
    local netid = TheNet:GetNetIdForUser(userid)
    if not netid then
        PEARL.error("Failed to retrive Steam ID for ", userid)
    else
        -- This should ALWAYS be string but just in case it's not...
        self:AddBinding(userid, tostring(netid), BINDING_TYPE.STEAM)
    end

    return record
end

-- Put stuff that's available from the start and doesn't change here.
--- @param userid string
function DB:AllocateRecordTableFor(userid)
    local record = deepcopy(RECORD_TEMPLATE)
    record.joinedtime = os.time()
    record.userid = userid

    return record
end

function DB:SaveToDatabaseFile(path, data, ensure, encode)
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
function DB:LoadDatabaseFile(path, ensure)
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

--- Loads a single binding file with the specified type from disk.
--- @return table<string, string>? bindings The binding data that was loaded from the file, if any.
function DB:LoadBindingFile(type)
    PEARL.info("Loading bindings from", type)

    local bindings = self:LoadDatabaseFile(PEARL.CONFIG.DATABASE.FOLDER.."/"..type, true)
    if not bindings then
        return PEARL.error("Failed to load binding file with type", type)
    end

    self._bindings[type] = bindings --setmetatable(bindings, CreateRecordMT(bindings))

    return bindings
end

--- Loads all binding files from disk.
function DB:LoadBindingFiles()
    for _, type in pairs(BINDING_TYPE) do
        self:LoadBindingFile(type)
    end
end

--- Saves the binding file with the specified type.
--- @param type string
function DB:SaveBindingFile(type)
    local bindings = self:GetBindings(type)
    if not bindings then
        return PEARL.error("Failed to load the binding file", type)
    end

    -- local mt = getmetatable(bindings)
    -- if mt and mt.__changes and mt.__changes <= 0 then
    --     return PEARL.debug("Not saving the binding file ", type, "because there were no changes made.")
    -- end

    PEARL.info("Saving binding file", type)

    self:SaveToDatabaseFile(PEARL.CONFIG.DATABASE.FOLDER.."/"..type, bindings, true)

    --setmetatable(bindings, CreateRecordMT(bindings))
end

--- Makes sure that the database record contains valid data and bindings.
--- @param record table<string, any>
function DB:ValidateRecord(record)
    local userid = record.userid
    for _, bindtype in pairs(BINDING_TYPE) do
        local mapped = self:MapUserIDToType(userid, bindtype)
        local saved  = record[BINDING_FIELD[bindtype]]

        if mapped ~= nil and saved ~= nil and mapped ~= saved then
            self:AddBinding(userid, mapped or saved, bindtype)
        end
    end
end

--- WARNING: This function doesn't cache the record!
--- Loads the record data from the actual database file for the given player.
--- @param userid string
--- @param validate boolean?
function DB:LoadRecordFor(userid, validate)
    PEARL.info("Loading record for ", userid.."...")

    local record = self:LoadDatabaseFile(self:GetRecordFilePathFor(userid))
    if type(record) ~= "table" then
        PEARL.error("Failed to load record for", userid)
        return
    end

    if validate == true then
        self:ValidateRecord(record)
    end

    return record
end

--- Save the database record data for the given player.
--- @param userid string
--- @param record table<string, any>?
function DB:SaveRecordFor(userid, record)
    PEARL.debug("SaveRecordFor", userid, record)

    record = record or self._records[userid]
    -- Only save data for users that have agreed to the agreement.
    --- @TODO: Re-think the data collection complication.
    --- @TODO: Make the first agreement screen popup up before joining the server.
    if not record then --or (not self:IsDataCollectionEnabledFor(userid) and force ~= true) then
        return PEARL.error("Record not found for", userid)
    end

    -- local mt = getmetatable(record)
    -- if mt and mt.__changes and mt.__changes <= 0 then
    --     return PEARL.debug("Not saving the record file because no changes were done!")
    -- end

    if not self:SaveToDatabaseFile(
        self:GetRecordFilePathFor(userid), record, true
    ) then
        PEARL.error("Failed to save record for", userid)
    end

    --setmetatable(record, CreateRecordMT(record))
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
    if DB:IsDisabled() then
        return
    end

    PEARL.info("Saving the database...")

    -- Save lastseentime, lastdays here as well, because we may be shutting down,
    -- or the server may crash during restarting/rollbacking
    local time_now = os.time()
    for userid, _ in pairs(DB._records) do
        if PEARL.ServerNetwork:IsUserConnected(userid) then
            DB:SafeSetField(userid, "lastseentime", time_now)
        end

        DB:SaveRecordFor(userid)
    end

    -- Save all loaded bindings in case the binding file got removed during our runtime.
    for bindtype, _ in pairs(DB._bindings) do
        DB:SaveBindingFile(bindtype)
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

return DB
