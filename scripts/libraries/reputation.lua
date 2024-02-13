--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--------------------------------------
-- [[ Constants ]]
--------------------------------------

local VERY_BAD_REP_THRESHOLD = PEARL.CONSTS.STARTING_REPUTATION / 4
local BAD_REP_THRESHOLD = PEARL.CONSTS.STARTING_REPUTATION / 2

--- Per action
local MAX_REP_EARN = 50
local MAX_REP_LOSE = -100

local MAX_REP_PER_CYCLE = 100

local REMEMBER_LOSE_THRESHOLD = -5

local NEGATIVE_REP_MULTIPLIER = 1
local MAX_REP_MULTIPLIER      = 2
local MIN_REP_MULTIPLIER      = 0

-- If we have lost at least REMEMBER_LOSE_THRESHOLD of reputation
-- we won't gain any reputation again until this cooldown finishes.
local GAIN_COOLDOWN = 60

-- In minutes
local EXP_NEWBIE_THRESHOLD  = 60 * 60
local EXP_NEUTRAL_THRESHOLD = 200 * 60

local FIELD_NAME = "reputation"

--------------------------------------
-- [[ Class Declaration ]]
--------------------------------------

--- @class Reputation
local Reputation = {
    sync_rep_table  = {},

    --- @type table<string, table<any, integer>>
    sources         = {},
}

--------------------------------------
-- [[ Static ]]
--------------------------------------

Reputation.DEFAULT_REP_DATA = {
    value = PEARL.CONSTS.STARTING_REPUTATION,
    peak = PEARL.CONSTS.STARTING_REPUTATION,
    lowest = PEARL.CONSTS.STARTING_REPUTATION,
    lastlose = 0,
    monthgains = 0,
    daygains = 0,
    cyclegains = 0,
}

Reputation.LIMIT = {
    NONE        = -1,
    WORST       = 0,
    VERY_BAD    = VERY_BAD_REP_THRESHOLD,
    BAD         = BAD_REP_THRESHOLD,
    NEUTRAL     = PEARL.CONSTS.STARTING_REPUTATION,
}

--------------------------------------
-- [[ Static ]]
--------------------------------------

--- @type number
Reputation.STARTING_VALUE = PEARL.CONSTS.STARTING_REPUTATION

--------------------------------------
-- [[ Getters ]]
--------------------------------------

function Reputation:GetFieldOf(userid, field)
    field = field or "value"

    if self.sync_rep_table[userid] ~= nil and self.sync_rep_table[userid][field] ~= nil then
        return self.sync_rep_table[userid][field]
    end

    return PEARL.DB:GetSubField(userid, FIELD_NAME, field)
end

--- @return number
function Reputation:GetOf(userid)
    return userid and tonumber(self:GetFieldOf(userid, "value") or nil) or Reputation.STARTING_VALUE
end

--- @return number
function Reputation:GetPeakOf(userid)
    return userid and self:GetFieldOf(userid, "peak") or 0
end

--- @return number
function Reputation:GetTodayGainsOf(userid)
    return userid and self:GetFieldOf(userid, "daygains") or 0
end

--- @return number
function Reputation:GetMonthGainsOf(userid)
    return userid and self:GetFieldOf(userid, "monthgains") or 0
end

--- @return number
function Reputation:GetCycleGains(userid)
    return userid and self:GetFieldOf(userid, "cyclegains") or 0
end

--- @return number
function Reputation:GetLowestOf(userid)
    return userid and self:GetFieldOf(userid, "lowest") or 0
end

function Reputation:GetGamePlayTime(userid)
    return PEARL.DB:GetField(userid, "gameplaytime")
end

-- Returns time in minutes spent actively playing on the server.
--- @return number
function Reputation:GetLocalGamePlayTime(userid)
    local totaldays = PEARL.DB:GetField(userid, "totaldays", 0)
    return (totaldays * TUNING.TOTAL_DAY_TIME) / 60
end

--------------------------------------
-- [[ Setters ]]
--------------------------------------

--- @param userid string
--- @param field string?
--- @param value any
function Reputation:SetFieldFor(userid, field, value, sync)
    if PEARL.DB:IsDisabled() or PEARL.CONFIG.PERMISSIVE_MODE or not PEARL.DB:HasRecordFile(userid) then
        return false
    end

    local record = PEARL.DB:GetRecordFor(userid)
    if not record then
        return false
    end

    local modifable = record["reputation"]
    -- When modifable is not really modifable.
    if record:IsReadOnly() then
        if sync ~= true then
            -- We will continue but this behaviour should not happen.
            PEARL.error("Attempted to modify player's reputation on a non-active shard!")
        end

        if not self.sync_rep_table[userid] then
            self.sync_rep_table[userid] = shallowcopy(modifable)
        end

        modifable = self.sync_rep_table[userid]
    end

    if type(modifable) ~= "table" then
        return false
    end

    field = field or "value"

    local old = modifable[field]
    modifable[field] = value

    if field == "value" and old ~= value then
        local delta = value - old
        local monthgains = self:GetMonthGainsOf(userid)
        self:SetFieldFor(userid, "monthgains", math.floor(monthgains + delta))
        local daygains = self:GetTodayGainsOf(userid)
        self:SetFieldFor(userid, "daygains", math.floor(daygains + delta))

        local peak = self:GetPeakOf(userid)
        if peak < value then
            self:SetFieldFor(userid, "peak", value)
        end

        local lowest = self:GetLowestOf(userid)
        if lowest > value then
            self:SetFieldFor(userid, "lowest", value)
        end

        PEARL.EventProcessor:HandleEvent("onreputationchanged", userid, old, value)
    end

    return true
end

function Reputation:SetFor(userid, value, sync)
    return self:SetFieldFor(userid, "value", value, sync)
end

--------------------------------------
-- [[ Public Methods ]]
--------------------------------------

--- @param userid string
--- @param delta number
--- @param limit number?
--- @return number
function Reputation:DoDeltaTo(userid, delta, limit)
    PEARL.debug("DoDeltaTo", userid, delta, limit)
    local rep = self:GetOf(userid)
    if limit and rep <= limit then
        return rep
    end

    delta = math.max(math.min(delta, MAX_REP_EARN), MAX_REP_LOSE)
    local new_rep = math.floor(rep + delta)
    if limit then
        new_rep = math.max(new_rep, limit)
    end

    self:SetFor(userid, new_rep)

    return new_rep
end

-- The more reputation they have the less they earn and vice versa.
--- @param userid string
--- @param amount number
--- @param limit number?
--- @param source any
function Reputation:EarnFor(userid, amount, limit, source)
    if PEARL.CONFIG.PERMISSIVE_MODE == true or amount == 0 then
        return
    end

    -- Preventing quick changes in reputation.
    local lastlose = self:GetFieldOf(userid, "lastlose")
    if lastlose and amount > 0 and lastlose > 0 and (os.time() - lastlose) < GAIN_COOLDOWN then
        return -- We are on cooldown!
    end

    local old_rep = self:GetOf(userid)
    local mult = NEGATIVE_REP_MULTIPLIER
    if amount > 0 then
        local gained = math.max(old_rep - Reputation.STARTING_VALUE, 0)
        mult = 1 / math.log10(gained^(math.logb(10, Reputation.STARTING_VALUE)))
        mult = math.max(math.min(mult, MAX_REP_MULTIPLIER), MIN_REP_MULTIPLIER)
        -- Make sure the multiplier is never zero.
        mult = mult <= 0 and MAX_REP_MULTIPLIER or mult
    end

    if source ~= nil then
        if not self.sources[userid] then
            self.sources[userid] = {}
        -- Leave the mult on the first occurence of the source alone.
        elseif self.sources[userid][source] then
            local occurs = math.max(self.sources[userid][source], 1)
            mult = amount > 0 and mult / occurs or mult * occurs
        end

        self.sources[userid][source] = (self.sources[userid][source] or 0) + 1
    end

    limit = limit or Reputation.LIMIT.BAD
    local new_rep = self:DoDeltaTo(userid, amount * mult, limit)
    if (new_rep - old_rep) <= REMEMBER_LOSE_THRESHOLD then
        self:SetFieldFor(userid, "lastlose", os.time())
    end

    PEARL.EventProcessor:HandleEvent("onreputationearned", userid, old_rep, new_rep)
end

-- This is for giving specific amounts of reputation to a player.
-- This amount is not being changed by any multiplayer.
-- This can't go bellow the minimal player reputation so the player wont get banned this way.
function Reputation:GiveTo(userid, amount)
    return self:DoDeltaTo(userid, amount, VERY_BAD_REP_THRESHOLD)
end

--- @param userid string
--- @param value number?
function Reputation:InitializeFor(userid, value)
    local data = deepcopy(Reputation.DEFAULT_REP_DATA)
    if PEARL.DB:SetField(userid, FIELD_NAME, data) then
        PEARL.EventProcessor:HandleEvent("onreputationchanged", userid, 0, tonumber(value) or data.value)
    end
end

function Reputation:LoadReputationTables()
    local ROOT_DIR = PEARL.ModPersistance:GetRootDirectoryPath()
    local REP_TABLES_PATH = ROOT_DIR.."/reputation_tables.json"
    local data = PEARL.ModPersistance:LoadDataFromFile(REP_TABLES_PATH, true)
    if data then
        for k, v in pairs(data) do
            PEARL.CONSTS.REPUTATION_TABLES[k] = v
        end
    end
    PEARL.ModPersistance:SaveDataToFile(REP_TABLES_PATH, PEARL.CONSTS.REPUTATION_TABLES, true, false)
end

--------------------------------------
-- [[ RPCs ]]
--------------------------------------

PEARL.AddShardRPCHandler("ReputationChanged", function(shardid, userid, new)
    Reputation:SetFor(userid, new)
end)

--------------------------------------
-- [[ Return ]]
--------------------------------------

return Reputation
