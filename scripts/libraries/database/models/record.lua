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

------------------------------------------
-- [[ Constants ]]
------------------------------------------

--- In case the value is function (functions cannot be JSON serialized) the function
--- is called and it's return value is used as the default value instead.
--- This allows for dynamic default values.
--- @type table<string, number|boolean|string|table>
local DEFAULT_FIELD_VALUES = {
    totaldays = 0,
    daysalive = 0,
    deathscount = 0,
}

--- @type table<string, fun(userid: string): number|boolean|string|table>
local DEFAULT_FIELD_FALLBACKS = {
    joinedtime = function(userid) return os.time() end,
    netid = function(userid) return TheNet:GetNetIdForUser(userid) end,
    userid = function(userid) return userid end,
    username = function(userid) return PEARL.GetUserName(userid) end,
}

local TOSTRING_PT = "<DatabaseRecord %s>[uptodate=%s]"

local DAY_IN_SECONDS = 24 * 60 * 60

------------------------------------------
-- [[ Class Declaration ]]
------------------------------------------

--- @class PlayerRecord
--- @field _data table
local PlayerRecord = Class(function(self, userid, data)
    PEARL.debug("PlayerRecord", userid)

    assert(type(userid) == "string", "Invalid userid provided!")
    assert(type(data) == "table", "Invalid data provided!")

    rawset(self, "_data", data)
    --- See __newindex fn
    rawset(self, "_uptodate", false) --rawset(self, "_uptodate", true)

    self._data.userid = userid
end)

------------------------------------------
-- [[ Static Fields ]]
------------------------------------------

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

------------------------------------------
-- [[ Meta Methods ]]
------------------------------------------

--- @TODO: Disabled until we figure out how to handle nested tables.
--- Flatting is also an option but it would be a pain in the ass for stuff like arrays.
-- function PlayerRecord:__newindex(field, value, ...)
--     if not self:IsWriteable() then
--         return PEARL.error("Attempted to modify a read-only record!")
--     end

--     if rawget(self._data, field) ~= value or type(value) == "table" then
--         rawset(self._data, field, value)

--         self:SetIsUpToDate(false)
--     end
-- end

function PlayerRecord:__index(field, ...)
    if self._data[field] ~= nil then
        return self._data[field]
    end

    local fn = rawget(PlayerRecord, field)
    if type(fn) == "function" then
        return fn
    end
end

function PlayerRecord:__tostring()
    return TOSTRING_PT:format(
        self._data.userid, tostring(self._uptodate)
    )
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
    --- See __newindex fn
    --self._uptodate = uptodate
end

------------------------------------------
-- [[ Public Functions ]]
------------------------------------------

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
