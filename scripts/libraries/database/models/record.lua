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

--- Put default non-dynamic record data here.
local DEFAULT_FIELDS = {
    joinedtime = nil,
    totaldays = 0,
    daysalive = 0,
    deathscount = 0,
    netid = nil,
    agreement = {
        --collectdata = false,
    },
}

local TOSTRING_PT = "<DatabaseRecord %s>[uptodate=%s]"

------------------------------------------
-- [[ Class Declaration ]]
------------------------------------------

--- @class PlayerRecord
local PlayerRecord = Class(function(self, userid)
    PEARL.debug("PlayerRecord", userid)
    assert(type(userid) == "string", "Invalid userid provided!")

    self._data = deepcopy(DEFAULT_FIELDS)
    print("INIT")
    self._data.joinedtime = os.time()
    self._data.userid = userid

    self._uptodate = true
    print("DONE")
end)

------------------------------------------
-- [[ Static Fields ]]
------------------------------------------

PlayerRecord.TEMPLATE = DEFAULT_FIELDS

------------------------------------------
-- [[ Meta Methods ]]
------------------------------------------

-- function PlayerRecord:__newindex(field, value, ...)
--     print("PlayerRecord.__newindex", self, field, value, ...)

--     if not self:IsWriteable() then
--         return PEARL.error("Attempted to modify a read-only record!")
--     end

--     if rawget(self._data, field) ~= value then
--         rawset(self._data, field, value)

--         self._uptodate = false
--     end
-- end

function PlayerRecord:__index(field, ...)
    print("PlayerRecord.__index", self, field, ...)

    if self._data[field] ~= nil then
        return self._data[field]
    end

    local fn = rawget(self, field)
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

--- @return boolean
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
        self:IsRecordActive(self._data.userid)
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

function PlayerRecord:SetIsUpToDate(uptodate)
    self._uptodate = uptodate
end

------------------------------------------
-- [[ Public Functions ]]
------------------------------------------

function PlayerRecord:Validate()
    --- Backwards compatibility in case we add new default fields.
    for field, value in pairs(DEFAULT_FIELDS) do
        if self._data[field] == nil then
            self._data[field] = value
        end
    end
end

------------------------------------------
-- [[ Return ]]
------------------------------------------

return PlayerRecord
