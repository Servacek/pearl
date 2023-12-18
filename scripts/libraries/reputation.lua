--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
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

local MAX_REP_EARN = 750
local MAX_REP_LOSE = -100

local REMEMBER_LOSE_THRESHOLD = -5

local NEGATIVE_REP_MULTIPLIER = 1

local REP_EARN_SCALE = 0.16
local REP_BASE = 1.39

-- If we have lost at least REMEMBER_LOSE_THRESHOLD of reputation
-- we won't gain any reputation again until this cooldown finishes.
local GAIN_COOLDOWN = 60

-- In minutes
local EXP_NEWBIE_THRESHOLD  = 60 * 60
local EXP_NEUTRAL_THRESHOLD = 200 * 60

local DEFAULT_REP_DATA = {
    value = PEARL.CONSTS.STARTING_REPUTATION,
    peak = PEARL.CONSTS.STARTING_REPUTATION,
    lowest = PEARL.CONSTS.STARTING_REPUTATION,
    lastlose = 0,
    monthgains = 0,
    daygains = 0,
}

local FIELD_NAME = "reputation"

--------------------------------------
-- [[ Class Declaration ]]
--------------------------------------

--- @class Reputation
local Reputation = {}

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

    return PEARL.DB:GetSubField(userid, "reputation", field)
end

--- @return number
function Reputation:GetOf(userid)
    return userid and tonumber(self:GetFieldOf(userid, "value")) or Reputation.STARTING_VALUE
end

function Reputation:GetPeakOf(userid)
    return userid and self:GetFieldOf(userid, "peak") or 0
end

function Reputation:GetTodayGainsOf(userid)
    return userid and self:GetFieldOf(userid, "daygains") or 0
end

function Reputation:GetMonthGainsOf(userid)
    return userid and self:GetFieldOf(userid, "monthgains") or 0
end

function Reputation:GetLowestOf(userid)
    return userid and self:GetFieldOf(userid, "lowest") or 0
end

--- @TODO: Handle special case for non-reputable users trying to display they own reputation.
function Reputation:IsReputable(userid)
    return not PEARL.AdminList:Contains(userid)
end

function Reputation:IsNewbie(userid)
    local playtime = PEARL.DB:GetField(userid, "gameplaytime")
    return playtime and playtime < EXP_NEWBIE_THRESHOLD or false
end

function Reputation:IsExperienced(userid)
    local playtime = PEARL.DB:GetField(userid, "gameplaytime")
    return playtime and playtime > EXP_NEUTRAL_THRESHOLD or false
end

--------------------------------------
-- [[ Setters ]]
--------------------------------------

--- @param userid string
--- @param field string?
--- @param value any
function Reputation:SetFieldFor(userid, field, value)
    if PEARL.DB:IsDisabled() or PEARL.CONFIG.PERMISSIVE_MODE then
        return false
    end

    local record = PEARL.DB:GetRecordFor(userid)
    if not record or type(record["reputation"]) ~= "table" then
        return false
    end

    field = field or "value"

    local old = record["reputation"][field]
    record["reputation"][field] = value

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

function Reputation:SetFor(userid, value)
    return self:SetFieldFor(userid, "value", value)
end

--------------------------------------
-- [[ Public Methods ]]
--------------------------------------

function Reputation:DoDeltaTo(userid, delta, limit)
    PEARL.debug("DoDeltaTo", userid, delta, limit)

    if PEARL.DB:IsDisabled() or PEARL.CONFIG.PERMISSIVE_MODE == true then
        return
    end

    if not PEARL.DB:HasRecordFile(userid) then
        PEARL.error("Record not found for", userid)
        return
    end

    local rep = self:GetOf(userid)
    delta = math.max(math.min(delta, MAX_REP_EARN), MAX_REP_LOSE)
    local new_rep = math.floor(rep + delta)
    if limit then
        new_rep = math.max(new_rep, limit)
    end

    self:SetFor(userid, new_rep)

    return new_rep
end

-- Players are earning reputation from their own in-game actions and behaviour.
-- The more reputation they have the less they earn and vice versa.
-- This has no limits if marked as griefing, so the reputation can go below zero
-- which then causes the player to be banned.
function Reputation:EarnFor(userid, amount, griefing)
    -- Preventing quick changes in reputation.
    local lastlose = self:GetFieldOf(userid, "lastlose")
    if amount > 0 and lastlose > 0 and (os.time() - lastlose) < GAIN_COOLDOWN then
        return -- We are on cooldown!
    end

    local old_rep = self:GetOf(userid)
    local gained = math.max(old_rep - Reputation.STARTING_VALUE, 0)
    local mult = REP_BASE / math.log(math.max(gained ^ REP_EARN_SCALE, 2))
    if amount < 0 then
        mult = NEGATIVE_REP_MULTIPLIER
    end

    -- Stop right before warnings would start. Only push warning when doing really bad things.
    local limit = not griefing and BAD_REP_THRESHOLD or nil
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

--- @param value number
--- @return boolean success
function Reputation:SetTo(userid, value)
    if type(value) == "number" then
        return self:SetFieldFor(userid, "value", value)
    else
        PEARL.error("Attempted to set an invalid reputation value: ", type(value), value)
    end

    return false
end

--- @param userid string
--- @param value number?
function Reputation:InitializeFor(userid, value)
    local data = deepcopy(DEFAULT_REP_DATA)
    if PEARL.DB:SetField(userid, FIELD_NAME, data) then
        PEARL.EventProcessor:HandleEvent("onreputationchanged", userid, 0, tonumber(value) or data.value)
    end
end

--------------------------------------
-- [[ Return ]]
--------------------------------------

return Reputation
