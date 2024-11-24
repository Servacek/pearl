--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

--[[
    The account bindings manager.

    Keep in mind every Klei ID can not have multiple bindings of the same type.
--]]

--- @TODO: Maybe we could handle the tables by overriding the __eq metamethod?

------------------------------------------
-- [[ Constants ]]
------------------------------------------

local FILE_EXTENSION = ".json"
local FILE_PATH = "/%s"..FILE_EXTENSION
local ROOT = PEARL.ModPersistence:GetRootDirectoryPath()
local DATABASE_ROOT_PATH = ROOT.."/"..PEARL.CONFIG.DATABASE.DIRECTORIES.ROOT
local DATABASE_BINDING_PATH = DATABASE_ROOT_PATH.."/"..PEARL.CONFIG.DATABASE.DIRECTORIES.BINDINGS..FILE_PATH

local BINDING_TYPE = {
    STEAMID     = "steamids",
    DISCORDID   = "discordids",
    USERNAME    = "usernames",
    SESSIONID   = "sessionids",
}

local BINDING_CATEGORY = {
    IDENTIFIER = { -- These will have always string as the value, never a table.
        BINDING_TYPE.STEAMID,
        BINDING_TYPE.DISCORDID,
    },
}

--- These fields should never be set or unset manually!
local BINDING_FIELD = {
    -- Shortcut used by the game, we inherit it for consistency.
    [BINDING_TYPE.STEAMID]      = "netid",
    [BINDING_TYPE.SESSIONID]    = "lastsessionid"
}
for name, type in pairs(BINDING_TYPE) do
    if BINDING_FIELD[type] == nil then
        BINDING_FIELD[type] = string.lower(name)
    end
end

------------------------------------------
-- [[ Class Declaration ]]
------------------------------------------

--- @singleton
--- @class AccountBindings
local AccountBindings = {
    _bindings = {},         --- @type table<string, table<string, table<string>|string>>
}

------------------------------------------
-- [[ Static ]]
------------------------------------------

AccountBindings.BINDING_TYPE    = BINDING_TYPE
AccountBindings.TYPE_TO_FIELD   = BINDING_FIELD
AccountBindings.FIELD_TO_TYPE   = table.invert(AccountBindings.TYPE_TO_FIELD)

--- All clients have this kind of binding
--- We use this as a list of all recorded userids to reduce complexity since
--- listing files is not allowed by the environment...
---
--- if needed, this can be changed later to some dedicated list or maybe some SFTP listing method or something...
AccountBindings.DEFAULT_BINDING_TYPE = BINDING_TYPE.STEAMID

------------------------------------------
-- [[ Private ]]
------------------------------------------

local function _AddToBindingsTable(bindings, userid, bindvalue)
    if bindings[bindvalue] == nil then
        bindings[bindvalue] = userid
    else
        if type(bindings[bindvalue]) == "table" then
            bindings[bindvalue][userid] = 1
        else
            bindings[bindvalue] = {[bindings[bindvalue]] = 1, [userid] = 1}
        end
    end
end

local function _RemoveFromBindTable(bindings, userid, bindvalue)
    if type(bindings[bindvalue]) == "table" then
        bindings[bindvalue][userid] = nil
        if table.size(bindings[bindvalue]) <= 1 then -- Remove empty tables (replace single element ones as well.)
            bindings[bindvalue] = next(bindings[bindvalue])
        end
    else
        bindings[bindvalue] = nil
    end
end

------------------------------------------
-- [[ Getters ]]
------------------------------------------

function AccountBindings:CountBindingsForType(bindtype)
    return self._bindings and table.size(self._bindings[bindtype]) or 0
end

function AccountBindings:GetBindingFilePath(bindtype)
    return bindtype and DATABASE_BINDING_PATH:format(bindtype)
end

function AccountBindings:BindingFileExists(bindtype)
    return io.exists(self:GetBindingFilePath(bindtype)) == true
end

--- @param bindtype string|table<string, number>
--- @return table<string, string|table<string, number>>? bindings
function AccountBindings:Get(bindtype)
    return self._bindings[bindtype]
end

--- @param bindtype string|table<string, number>
--- @return table<string>? userids
function AccountBindings:GetUserIDs(bindtype)
    local userids = {}
    for _, userid in pairs(self._bindings[bindtype]) do
        if type(userid) == "table" then
            table.join(userids, userid)
        else
            userids[#userids+1] = userid
        end
    end

    return userids
end

--- Checks whether userid is bound with value in any way.
--- @return boolean
function AccountBindings:Exists(userid, value, bindtype)
    local binduserid = self._bindings[bindtype][value]
    if type(binduserid) == "table" then
        return binduserid[userid] ~= nil
    end

    return (-- The binding must exist in both files in order to be marked as existing.
        self._bindings[bindtype][value] == userid and PEARL.DB:GetField(userid, BINDING_FIELD[bindtype]) == value
    )
end

--- @return boolean
function AccountBindings:IsFieldBindable(field)
    return AccountBindings.FIELD_TO_TYPE[field] ~= nil
end

------------------------------------------
-- [[ Public Functions ]]
------------------------------------------

--- @param record PlayerRecord
function AccountBindings:ValidateForRecord(record)
    local userid = record.userid
    for _, bindtype in pairs(BINDING_TYPE) do
        local mapped
        for k, v in pairs(self._bindings[bindtype]) do
            if v == userid or type(v) == "table" and v[userid] then
                mapped = tostring(k)
            end
        end

        local recorded = record[BINDING_FIELD[bindtype]]
        local value = mapped or recorded

        if value ~= nil and not self:Exists(userid, value, bindtype) then
            self:AddBinding(userid, value, bindtype)
        end
    end
end

--- @return string? userid
function AccountBindings:MapSteamID(steamid)
    return self._bindings[BINDING_TYPE.STEAMID][steamid] --- @type string? (IDENTIFIER)
end

--- @return string? userid
function AccountBindings:MapDiscordID(discordid)
    return self._bindings[BINDING_TYPE.DISCORDID][discordid] --- @type string? (IDENTIFIER)
end

--- Receives an ID and attempts to convert it to a Klei ID using all the bindings available.
--- @return string? userid
function AccountBindings:MapToKleiID(id)
    for _, bindtype in pairs(BINDING_CATEGORY.IDENTIFIER) do
        if self._bindings[bindtype] and type(self._bindings[bindtype][id]) == "string" then
            return self._bindings[bindtype][id] --- @type string? (IDENTIFIER)
        end
    end
end

--- @param userid string
--- @param bindtype string
--- @return string? bindvalue
function AccountBindings:MapUserIDToBindValue(userid, bindtype)
    --- if the binding actually exists, this should never fail.
    return PEARL.DB:GetField(userid, BINDING_FIELD[bindtype])
end

--- @return string|table<string, number>?
function AccountBindings:MapBindValueToUserID(bindtype, bindvalue)
    return self._bindings[bindtype] and self._bindings[bindtype][bindvalue]
end

--- @return table<string, string|table<string, number>>
function AccountBindings:GenerateForType(bindtype)
    local bindings = {}
    for _, userid in ipairs(PEARL.DB:GetAllRecordedUserIDs()) do
        local bindvalue = PEARL.DB:GetField(userid, BINDING_FIELD[bindtype])
        if bindvalue ~= nil then
            _AddToBindingsTable(bindings, userid, bindvalue)
        end
    end

    return bindings
end

-- Userids are mapped by Steam IDs for easier access.
-- We store the whole list of IDs so we can traverse all records if needed,
-- since we cannot list files.
--- @param userid string
--- @param bindvalue string
--- @param bindtype string
function AccountBindings:AddBinding(userid, bindvalue, bindtype)
    local bindings = self:Get(bindtype)
    if not bindings then
        return PEARL.error("Invalid binding type provided!")
    end

    if self:Exists(userid, bindvalue, bindtype) then
        return PEARL.debug("Binding", bindvalue, "->", userid, "already exists.")
    end

    local previous_bindvalue = self:MapUserIDToBindValue(userid, bindtype)
    _AddToBindingsTable(bindings, userid, bindvalue)
    PEARL.DB:SetField(userid, BINDING_FIELD[bindtype], bindvalue)
    if previous_bindvalue ~= nil then
        PEARL.debug("Removing previous bind value", previous_bindvalue)
        _RemoveFromBindTable(bindings, userid, previous_bindvalue)
    end

    -- We have to save after every adding because there is no global saving for binding files.
    -- Also save the userid list here, because this is the only place
    -- where we are modifying it in some way.
    -- We want to make sure that the info there is always up-to-date
    -- with the record files created in case of some unexcpected shutdowns or crashes.
    self:SaveForType(bindtype)

    PEARL.debug("Binding", bindvalue, "->", userid, "successfully added!")
end

--- @param userid string
--- @param bindvalue string
--- @param bindtype string
function AccountBindings:RemoveBinding(userid, bindvalue, bindtype)
    local bindings = self:Get(bindtype)
    if not bindings then
        return PEARL.error("Invalid binding type provided!")
    end

    local previous_binduserid = bindings[bindvalue]
    _RemoveFromBindTable(bindings, userid, bindvalue)
    local success, prev = PEARL.DB:SetField(userid, BINDING_FIELD[bindtype], nil)

    if (success and prev ~= nil) or previous_binduserid ~= nil then
        self:SaveForType(bindtype)

        PEARL.debug("Binding", bindvalue, "->", userid, "successfully removed!")
    end
end

--- Loads a single binding file with the specified type from disk.
--- @return table<string, table<string>|string>? bindings The binding data that was loaded from the file, if any.
function AccountBindings:LoadForType(bindtype)
    PEARL.info("Loading bindings from", bindtype)

    local path = self:GetBindingFilePath(bindtype)
    local bindings = PEARL.ModPersistence:LoadDataFromFile(path)
    if type(bindings) ~= "table" then -- Either not existing or corrupt, so create new data.
        PEARL.error("Failed to load binding file with type", bindtype)

        self._bindings[bindtype] = self:GenerateForType(bindtype)
        self:SaveForType(bindtype)
    else
        self._bindings[bindtype] = bindings
    end

    return self._bindings[bindtype]
end

--- Loads all binding files from disk.
function AccountBindings:Load()
    PEARL.debug("Loading account bindings...")

    self:LoadForType(AccountBindings.DEFAULT_BINDING_TYPE)
    for _, bindtype in pairs(BINDING_TYPE) do
        if bindtype ~= AccountBindings.DEFAULT_BINDING_TYPE then -- Already loaded
            self:LoadForType(bindtype)
        end
    end
end

--- Saves the binding file with the specified type.
--- @param bindtype string
function AccountBindings:SaveForType(bindtype)
    local bindings = self:Get(bindtype)
    if not bindings then
        return PEARL.error("Failed to load the binding file", bindtype)
    end

    PEARL.info("Saving binding file", bindtype)
    PEARL.ModPersistence:SaveDataToFile(self:GetBindingFilePath(bindtype), bindings)
end

------------------------------------------
-- [[ Event Handlers ]]
------------------------------------------

local function OnSave()
    -- Save all loaded bindings in case the binding file got removed during our runtime.
    for bindtype, _ in pairs(AccountBindings._bindings) do
        if not AccountBindings:BindingFileExists(bindtype) then
            AccountBindings:SaveForType(bindtype)
        end
    end
end

------------------------------------------
-- [[ Event Listeners ]]
------------------------------------------

if not PEARL.CONFIG.DEBUG_MODE then -- To make regenerating the files in dev branch easier
    PEARL.EventProcessor:AddSafeEventHandler("save", OnSave)
    PEARL.EventProcessor:AddSafeEventHandler("quit", OnSave)
end

------------------------------------------
-- [[ Return ]]
------------------------------------------

return AccountBindings
