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
-- [[ Localization ]]
------------------------------------------

local rawget, rawset =  rawget, rawset
local deepcopy = PEARL.deepcopy
local type = type

------------------------------------------
-- [[ Constants ]]
------------------------------------------

--- In case the value is function (functions cannot be JSON serialized) the function
--- is called and it's return value is used as the default value instead.
--- This allows for dynamic default values.
--- @enum PlayerRecord.DEFAULT_FIELD_VALUES
--- @type table<string, number|boolean|string|table>
local DEFAULT_FIELD_VALUES = {
    totaldays = 0,
    daysalive = 0,
    deathscount = 0,
}

--- @enum PlayerRecord.DEFAULT_FIELD_FALLBACKS
--- @type table<string, fun(userid: string): number|boolean|string|table>
local DEFAULT_FIELD_FALLBACKS = {
    joinedtime = function(userid) return os.time() end,
    netid = function(userid) return TheNet:GetNetIdForUser(userid) end,
    userid = function(userid) return userid end,
    username = function(userid)
        local client = userid and TheNet:GetClientTableForUser(userid)
        return client and client.name or "UNKNOWN"
    end,
}

local TOSTRING_PT = "<DatabaseRecord %s>[uptodate=%s,userid=%s]"

local DAY_IN_SECONDS = 24 * 60 * 60

------------------------------------------
-- [[ Class Declaration ]]
------------------------------------------

--- @class PlayerRecord
--- @field _data table
local PlayerRecord = Class(function(self, userid, data)
    --PEARL.debug("PlayerRecord", userid)

    self:Init(userid, data)
end)

------------------------------------------
-- [[ Meta Methods ]]
------------------------------------------
--- So the way this is implemented, it doesn't support nested tables.
--- That means any changes deeper than the first layer won't get tracked.
--- There is no easy solution for this without terrible complex logic full of bugs.
--- So the structure of the record should follow the following rules:
---     1. Flatten everything that can be flatten without losing to much (i. e. arrays).
---     2. When working with arrays, always "DB:SetField()" them after a change was made.
---        Since the nature of the data, we do not use much arrays so that's not a problem
---        and even when an array has to be used the data inside it usually doesn't change much if ever.

function PlayerRecord:__newindex(field, value)
    if not self:IsWriteable() then
        return PEARL.error("Attempted to modify a read-only record!", CalledFrom())
    end

    -- Verify if new field names are valid.
    if self._data[field] == nil then
        if rawget(PlayerRecord, field) ~= nil then
            return error("Naming conflict! Field "..field.." already exists within the class itself!")
        end

        if not field:islowercase() then
            return error("Field "..field.." with value "..tostring(value).." is not in the recommended lowercase format!")
        end
    end

    if self._data[field] ~= value or type(value) == "table" then
        self._data[field] = value

        self:SetIsUpToDate(false)
    end
end

--- More modern approach to PlayerRecord:Get
--- Called only for fields not found in the instance table.
function PlayerRecord:__index(field)
    local fn = rawget(PlayerRecord, field) -- Handle class method access
    if type(fn) == "function" then
        return fn
    end

    local value = self._data[field]
    if value ~= nil then
        return value
    end

    local default = PlayerRecord.GetDefaultForField(field, self._data.userid)
    if default ~= nil then
        -- Make sure we save the defaults as well, since it may not be available the next time.
        -- This is especially usefull for dynamic default values.
        self._data[field] = default
    end

    return default
end

function PlayerRecord:__tostring()
    return TOSTRING_PT:format(
        PEARL.memaddr(self._data), tostring(self._uptodate), self._data.userid
    )
end

------------------------------------------
-- [[ Static Fields ]]
------------------------------------------

PlayerRecord.DEFAULT_FIELD_VALUES = DEFAULT_FIELD_VALUES
PlayerRecord.DEFAULT_FIELD_FALLBACKS = DEFAULT_FIELD_FALLBACKS

PlayerRecord.TEMPLATE = DEFAULT_FIELD_VALUES

--- @param userid string
--- @return PlayerRecord
function PlayerRecord.New(userid)
    local data = deepcopy(DEFAULT_FIELD_VALUES)
    data.joinedtime = os.time()

    local record = PlayerRecord(userid, data)
    record:SetIsUpToDate(false)

    return record
end

--- @param defaults table<string, any>
function PlayerRecord.AddFieldDefaults(defaults)
    table.update(DEFAULT_FIELD_VALUES, defaults)
end

--- @param field Reputation.FIELD
--- @param userid string? The ID of the player this field belongs to (used for dynamic defaults).
--- @return any
function PlayerRecord.GetDefaultForField(field, userid)
    if userid ~= nil and DEFAULT_FIELD_FALLBACKS[field] then
        return deepcopy(DEFAULT_FIELD_FALLBACKS[field](userid))
    end

    return deepcopy(DEFAULT_FIELD_VALUES[field])
end

------------------------------------------
-- [[ Getters ]]
------------------------------------------

--- @return table
function PlayerRecord:GetData()
    return self._data
end

--- @return boolean
function PlayerRecord:IsActive()
    -- This should actually check if the last shardid is the current shardid,
    -- but this way its more reliable.
    return PEARL.ServerNetwork:IsClientConnected(self._data.userid)
end

--- @return boolean
function PlayerRecord:IsWriteable()
    return self._data.lastshardid == nil or self._data.lastshardid == PEARL.SHARDID or
        not PEARL.ServerNetwork:IsClientConnectedAny(self._data.userid) or
        self:IsActive()
end

--- @return boolean
function PlayerRecord:IsNovice()
    if not self._data.joinedtime then
        return false
    end

    local currenttime = os.time()
    local joinedday = tonumber(PEARL.GetFieldFromTimestamp(self._data.joinedtime, "%d"))
    local currentday = tonumber(PEARL.GetFieldFromTimestamp(currenttime, "%d"))
    local timediff = os.difftime(currenttime, self._data.joinedtime)
    if timediff > DAY_IN_SECONDS then
        return false
    end

    return joinedday == currentday
end

--- @return table?
function PlayerRecord:GetLastBan()
    return self._data.bans and self._data.bans[#self._data.bans]
end

--- @return boolean
function PlayerRecord:IsReadOnly()
    return not self:IsWriteable()
end

function PlayerRecord:IsUpToDate()
    return self._uptodate == true
end

------------------------------------------
-- [[ Setters ]]
------------------------------------------

function PlayerRecord:SetData(data)
    self._data = data
end

function PlayerRecord:SetIsUpToDate(uptodate)
    PEARL.debug("PlayerRecord:SetIsUpToDate", uptodate)
    self._uptodate = uptodate
end

------------------------------------------
-- [[ Public Functions ]]
------------------------------------------

function PlayerRecord:Init(userid, data)
    assert(type(userid) == "string", "Invalid userid provided!")
    assert(type(data) == "table", "Invalid data provided!")

    data.userid = userid

    --- These have to be "rawset" the first time, so they do not push our custom metamethods.
    rawset(self, "_data", data)
    rawset(self, "_uptodate", true)

    return self
end

function PlayerRecord:Validate(userid)
    --- Backwards compatibility in case we add new default fields.
    for field, value in pairs(DEFAULT_FIELD_VALUES) do
        if self._data[field] == nil then
            if type(value) == "function" then
                self._data[field] = value(userid)
            else
                self._data[field] = value
            end
        end
    end

    for field, value in pairs(DEFAULT_FIELD_FALLBACKS) do
        if self._data[field] == nil then
            self._data[field] = value(userid)
        end
    end
end

------------------------------------------
-- [[ Return ]]
------------------------------------------

return PlayerRecord
