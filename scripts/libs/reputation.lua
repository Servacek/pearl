--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local PlayerRecord = PEARL.loadfile("libs/database/models/record")

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
-- local EXP_NEWBIE_THRESHOLD  = 60 * 60
-- local EXP_NEUTRAL_THRESHOLD = 200 * 60

local BASE_FIELD_NAME = "reputation"
local BASE_FIELD_PATTERN = BASE_FIELD_NAME..".%s"

local DISPLAY_DECIMAL_PLACES = 2

--------------------------------------
-- [[ Class Declaration ]]
--------------------------------------

--- @singleton
--- @class Reputation
local Reputation = {
    sync_rep_table  = {}, --- @type table<string, table<any, integer>>
    sources         = {}, --- @type table<string, table<any, integer>>
    limiters        = {}, --- @type table<number, fun(userid: string, rep: number, delta: number, limit: Reputation.LIMIT?)>
}

--------------------------------------
-- [[ Static ]]s
--------------------------------------

Reputation.STARTING_VALUE           = PEARL.CONSTS.STARTING_REPUTATION  --- @type number
Reputation.BAD_REP_THRESHOLD        = BAD_REP_THRESHOLD                 --- @type number
Reputation.START_WARNINGS_AT        = BAD_REP_THRESHOLD                 --- @type number

Reputation.DISPLAY_DECIMAL_PLACES   = 2                                 --- @type number

--- @enum Reputation.LIMIT
Reputation.LIMIT = {
    WORST       = -100,
    VERY_BAD    = VERY_BAD_REP_THRESHOLD,
    BAD         = BAD_REP_THRESHOLD,
    NEUTRAL     = PEARL.CONSTS.STARTING_REPUTATION,
}

Reputation.BASE_FIELD = BASE_FIELD_NAME
Reputation.BASE_FIELD_DEFAULT = 0

--- @enum Reputation.FIELD
Reputation.FIELD = {
    VALUE       = BASE_FIELD_PATTERN:format("value"),
    PEAK        = BASE_FIELD_PATTERN:format("peak"),
    LOWEST      = BASE_FIELD_PATTERN:format("lowest"),
    LASTLOSE    = BASE_FIELD_PATTERN:format("lastlose"),
    MONTHGAINS  = BASE_FIELD_PATTERN:format("monthgains"),
    DAYGAINS    = BASE_FIELD_PATTERN:format("daygains"),
    CYCLEGAINS  = BASE_FIELD_PATTERN:format("cyclegains"),
}

--- @enum Reputation.FIELD_DEFAULT
Reputation.FIELD_DEFAULT = {
    [Reputation.FIELD.VALUE] = PEARL.CONSTS.STARTING_REPUTATION,
    [Reputation.FIELD.PEAK] = PEARL.CONSTS.STARTING_REPUTATION,
    [Reputation.FIELD.LOWEST] = PEARL.CONSTS.STARTING_REPUTATION,
}

for _, field_name in pairs(Reputation.FIELD) do
    if Reputation.FIELD_DEFAULT[field_name] == nil then
        Reputation.FIELD_DEFAULT[field_name] = Reputation.BASE_FIELD_DEFAULT
    end
end

PlayerRecord.AddFieldDefaults(Reputation.FIELD_DEFAULT)

--------------------------------------
-- [[ Getters ]]
--------------------------------------

--- Returns a field normalized and ready to be displayed.
--- @param userid string
--- @param field Reputation.FIELD Defaults to Reputation.FIELD.VALUE
--- @param dp integer? Number of decimal places to round to, defaults to DISPLAY_DECIMAL_PLACES
--- @return any
function Reputation:GetDisplayField(userid, field, dp)
    PEARL.debug("Reputation:GetFieldOf", userid, field)

    local value = self:GetFieldOf(userid, field)
    return type(value) == "number" and math.round(value, dp or DISPLAY_DECIMAL_PLACES) or value
end

--- @param userid string
--- @param field Reputation.FIELD Defaults to Reputation.FIELD.VALUE
--- @return any
function Reputation:GetFieldOf(userid, field)
    PEARL.debug("Reputation:GetFieldOf", userid, field)

    field = field or Reputation.FIELD.VALUE
    if self.sync_rep_table[userid] ~= nil and self.sync_rep_table[userid][field] ~= nil then
        return self.sync_rep_table[userid][field]
    end

    return PEARL.DB:GetField(userid, field)
end

--- @return number
function Reputation:GetOf(userid, dp)
    local value = PEARL.Reputation:GetFieldOf(userid, Reputation.FIELD.VALUE)
    return dp ~= nil and math.round(value, dp) or value
end

--------------------------------------
-- [[ Setters ]]
--------------------------------------

--- @param userid string
--- @param field string?
--- @param value any
function Reputation:SetFieldFor(userid, field, value, sync)
    if PEARL.CONFIG.PERMISSIVE_MODE then
        return false
    end

    local record = PEARL.DB:GetRecordFor(userid)
    if not record then
        return false
    end

    local modifable = record
    -- When modifable is not really modifable.
    if record:IsReadOnly() then
        if sync ~= true then
            -- We will continue but this behaviour should not happen.
            PEARL.error("Attempted to modify player's reputation on a non-active shard!")
        end

        if not self.sync_rep_table[userid] then
            self.sync_rep_table[userid] = shallowcopy(Reputation.FIELD_DEFAULT)
        end

        modifable = self.sync_rep_table[userid]
    end

    if type(modifable) ~= "table" then
        return false
    end

    field = field or Reputation.FIELD.VALUE

    local old = modifable[field]
    modifable[field] = value

    if field == Reputation.FIELD.VALUE and old ~= value then
        local delta = value - old

        local monthgains = self:GetFieldOf(userid, Reputation.FIELD.MONTHGAINS)
        self:SetFieldFor(userid, Reputation.FIELD.MONTHGAINS, monthgains + delta)
        local daygains = self:GetFieldOf(userid, Reputation.FIELD.DAYGAINS)
        self:SetFieldFor(userid, Reputation.FIELD.DAYGAINS, daygains + delta)

        if PEARL.ServerNetwork:IsClientConnectedAny(userid) then
            local cyclegains = self:GetFieldOf(userid, Reputation.FIELD.CYCLEGAINS)
            self:SetFieldFor(userid, Reputation.FIELD.CYCLEGAINS, cyclegains + delta)
        end

        if self:GetFieldOf(userid, Reputation.FIELD.PEAK) < value then
            self:SetFieldFor(userid, Reputation.FIELD.PEAK, value)
        end

        if self:GetFieldOf(userid, Reputation.FIELD.LOWEST) > value then
            self:SetFieldFor(userid, Reputation.FIELD.LOWEST, value)
        end

        PEARL.EventProcessor:HandleEvent("onreputationchanged", userid, old, value)
    end

    return true
end

function Reputation:SetFor(userid, value, sync)
    return self:SetFieldFor(userid, Reputation.FIELD.VALUE, value, sync)
end

function Reputation:ResetFieldFor(userid, field)
    PEARL.debug("Reputation:ResetFieldFor", userid, field,Reputation.FIELD_DEFAULT[field])
    return self:SetFieldFor(userid, field, Reputation.FIELD_DEFAULT[field])
end

function Reputation:ResetFor(userid)
    for field, default_value in pairs(Reputation.FIELD_DEFAULT) do
        self:SetFieldFor(userid, field, default_value)
    end
end

--------------------------------------
-- [[ Public Methods ]]
--------------------------------------
--- There are three main ways to gain/loose reputation:
--- 1. By griefing.
--- 2. By contributing to the server.
--- 3. By a player who gives it to you using /giverep

function Reputation:AddDeltaLimiter(fn)
    table.insert(self.limiters, fn)
end

--- @param userid string
--- @param delta number
--- @param limit number?
--- @return number
function Reputation:DoDeltaTo(userid, delta, limit)
    PEARL.debug("DoDeltaTo", userid, delta, limit)
    local rep = self:GetOf(userid)
    for _, limitfn in ipairs(self.limiters) do
        local new_limit = limitfn(userid, rep, delta, limit)
        if not limit or new_limit > limit then -- Get the highest limit possible
            limit = new_limit
        end
    end

    if limit and rep <= limit then
        return rep
    end

    delta = math.max(math.min(delta, MAX_REP_EARN), MAX_REP_LOSE)
    local new_rep = rep + delta -- No flooring here so we do not lose information
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
    if PEARL.CONFIG.PERMISSIVE_MODE == true or amount == 0 or not userid then
        return
    end

    -- Preventing quick changes in reputation.
    local lastlose = self:GetFieldOf(userid, Reputation.FIELD.LASTLOSE)
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
        self:SetFieldFor(userid, Reputation.FIELD.LASTLOSE, os.time())
    end

    PEARL.EventProcessor:HandleEvent("onreputationearned", userid, old_rep, new_rep)
end

-- This is for giving specific amounts of reputation to a player.
-- This amount is not being changed by any multiplayer.
-- This can't go bellow the minimal player reputation so the player wont get banned this way.
function Reputation:GiveTo(userid, amount)
    -- Make sure the player wont receive any "griefing" warnings for reputation given by players.
    return self:DoDeltaTo(userid, amount, Reputation.START_WARNINGS_AT)
end

-- So the constants are not hardcoded.
function Reputation:LoadReputationTables()
    PEARL.info("Loading reputation tables...")

    local ROOT_DIR = PEARL.ModPersistence:GetRootDirectoryPath()
    local REP_TABLES_PATH = ROOT_DIR.."/reputation_tables.json"
    local data = PEARL.ModPersistence:LoadDataFromFile(REP_TABLES_PATH, true)
    if data then
        for k, v in pairs(data) do
            PEARL.CONSTS.REPUTATION_TABLES[k] = v
        end
    end

    PEARL.ModPersistence:SaveDataToFile(REP_TABLES_PATH, PEARL.CONSTS.REPUTATION_TABLES, false)
end

--------------------------------------
-- [[ RPCs ]]
--------------------------------------

PEARL.AddShardRPCHandler("ReputationChanged", function(shardid, userid, new)
    Reputation:SetFor(userid, new, true)
end)

--------------------------------------
-- [[ Return ]]
--------------------------------------

return Reputation
