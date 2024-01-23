--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

------------------------------------------
-- [[ Constants ]]
------------------------------------------

local FILE_EXTENSION = ".json"
local FILE_PATH = "/%s"..FILE_EXTENSION
local ROOT = PEARL.ModPersistance:GetRootDirectoryPath()
local DATABASE_ROOT_PATH = ROOT.."/"..PEARL.CONFIG.DATABASE.DIRECTORIES.ROOT
local DATABASE_BINDING_PATH = DATABASE_ROOT_PATH.."/"..PEARL.CONFIG.DATABASE.DIRECTORIES.BINDINGS..FILE_PATH

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

------------------------------------------
-- [[ Class Declaration ]]
------------------------------------------

--- @singleton
--- @class AccountBindings
local AccountBindings = {
    --- @type table<string, table?>
    _bindings = {
        [BINDING_TYPE.DISCORD]  = nil,
        [BINDING_TYPE.STEAM]    = nil,
    }
}

------------------------------------------
-- [[ Static ]]
------------------------------------------

AccountBindings.BINDING_TYPE    = BINDING_TYPE
AccountBindings.BINDING_FIELD   = BINDING_FIELD

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

--- @param bindtype string
--- @return table? bindings
function AccountBindings:Get(bindtype)
    return self._bindings[bindtype]
end


function AccountBindings:Exists(userid, bindid, bindtype)
    return (
        -- The binding must exist in both files in order to be marked as existing.
        self._bindings[bindtype][bindid] == userid and PEARL.DB:GetField(userid, BINDING_FIELD[bindtype]) == bindid
    )
end

function AccountBindings:ExistsAny(userid, bindtype)
    return (
        table.contains(self._bindings[bindtype], userid)
    )
end

------------------------------------------
-- [[ Public Functions ]]
------------------------------------------

--- @param record PlayerRecord
function AccountBindings:ValidateForRecord(record)
    local userid = record.userid
    for _, bindtype in pairs(BINDING_TYPE) do
        local mapped = self:MapUserIDToType(userid, bindtype)
        local saved  = record[BINDING_FIELD[bindtype]]

        if mapped ~= nil and saved ~= nil and mapped ~= saved then
            self:AddBinding(userid, mapped or saved, bindtype)
        end
    end
end

--- @return string? userid
function AccountBindings:MapSteamID(steamid)
    return self._bindings[BINDING_TYPE.STEAM][steamid]
end

--- @return string? userid
function AccountBindings:MapDiscordID(discordid)
    return self._bindings[BINDING_TYPE.DISCORD][discordid]
end

--- Receives an ID and attempts to convert it to a Klei ID using all the bindings available.
--- @return string? userid
function AccountBindings:MapToKleiID(id)
    for _, bindings in pairs(self._bindings) do
        if type(bindings[id]) == "string" then
            return bindings[id]
        end
    end
end

--- @param userid string
--- @param bindtype string
--- @return string? bindid
function AccountBindings:MapUserIDToType(userid, bindtype)
    if userid then
        return
    end

    local bindid = PEARL.DB:GetField(userid, BINDING_FIELD[bindtype])
    if bindid then
        return bindid
    end

    bindid = table.getkey(self._bindings[bindtype], userid)
    if bindid ~= nil then
        return tostring(bindid)
    end
end

-- Userids are mapped by Steam IDs for easier access.
-- We store the whole list of IDs so we can traverse all records if needed,
-- since we cannot list files.
--- @param userid string
--- @param bindid string
--- @param bindtype string
function AccountBindings:AddBinding(userid, bindid, bindtype)
    if self:Exists(userid, bindid, bindtype) then
        return PEARL.error("Binding", bindid, "->", userid, "already exists!")
    end

    self._bindings[bindtype][bindid] = userid
    PEARL.DB:SetField(userid, BINDING_FIELD[bindtype], bindid)

    -- We have to save after every adding because there is no global saving for binding files.
    -- Also save the userid list here, because this is the only place
    -- where we are modifying it in some way.
    -- We want to make sure that the info there is always up-to-date
    -- with the record files created in case of some unexcpected shutdowns or crashes.
    self:SaveForType(bindtype)

    PEARL.debug("Binding", bindid, "->", userid, "successfully added!")
end


--- @param userid string
--- @param bindid string
--- @param bindtype string
function AccountBindings:RemoveBinding(userid, bindid, bindtype)
    local bindings = self:Get(bindtype)
    if not bindings then
        return PEARL.error("Invalid binding type provided!")
    end

    local prev_val = bindings[bindid]
    bindings[bindid] = nil
    local success, prev = PEARL.DB:SetField(userid, BINDING_FIELD[bindtype], nil)

    if (success and prev ~= nil) or prev_val ~= nil then
        self:SaveForType(bindtype)

        PEARL.debug("Binding", bindid, "->", userid, "successfully removed!")
    end
end

--- Loads a single binding file with the specified type from disk.
--- @return table<string, string>? bindings The binding data that was loaded from the file, if any.
function AccountBindings:LoadForType(bindtype)
    PEARL.info("Loading bindings from", bindtype)

    local path = self:GetBindingFilePath(bindtype)
    local bindings = PEARL.ModPersistance:LoadDataFromFile(path, true)
    if type(bindings) ~= "table" then
        self._bindings[bindtype] = {}
        self:SaveForType(bindtype)

        return PEARL.error("Failed to load binding file with type", bindtype)
    end

    self._bindings[bindtype] = bindings

    return bindings
end

--- Loads all binding files from disk.
function AccountBindings:Load()
    PEARL.debug("Loading account bindings...")

    for _, bindtype in pairs(BINDING_TYPE) do
        self:LoadForType(bindtype)
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
    PEARL.ModPersistance:SaveDataToFile(self:GetBindingFilePath(bindtype), bindings, true)
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

PEARL.EventProcessor:AddSafeEventHandler("save", OnSave)
PEARL.EventProcessor:AddSafeEventHandler("quit", OnSave)

------------------------------------------
-- [[ Return ]]
------------------------------------------

return AccountBindings
