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

local STARTING_REPUTATION = PEARL.CONSTS.STARTING_REPUTATION

local BAD_REP_THRESHOLD = 25

local LOW_REP_THRESHOLD  = PEARL.CONSTS.STARTING_REPUTATION * 2
local LOW_REP_MULTIPLIER = 2

local MAX_REP_EARN = 750

local NEGATIVE_REP_MULTIPLIER = 1

local REP_EARN_SCALE = 0.16
local REP_BASE = 1.39

-- In minutes
local EXP_NEWBIE_THRESHOLD  = 60 * 60
local EXP_NEUTRAL_THRESHOLD = 200 * 60

local DEFAULT_REP_DATA = {
    value = PEARL.CONSTS.STARTING_REPUTATION,
    peak = PEARL.CONSTS.STARTING_REPUTATION,
    lowest = PEARL.CONSTS.STARTING_REPUTATION,
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
-- [[ Getters ]]
--------------------------------------

function Reputation:GetRepFieldOf(userid, field)
    field = field or "value"

    return PEARL.DB:GetSubField(userid, "reputation", field)
end

function Reputation:GetOf(userid)
    return self:GetRepFieldOf(userid)
end

function Reputation:GetPeakOf(userid)
    return userid and self:GetRepFieldOf(userid, "peak") or 0
end

function Reputation:GetTodayGainsOf(userid)
    return userid and self:GetRepFieldOf(userid, "daygains") or 0
end

function Reputation:GetMonthGainsOf(userid)
    return userid and self:GetRepFieldOf(userid, "monthgains") or 0
end

function Reputation:GetLowestOf(userid)
    return userid and self:GetRepFieldOf(userid, "lowest") or 0
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

function Reputation:SetFieldFor(userid, field, value)
    field = field or "value"

    local record = PEARL.DB:GetRecordFor(userid)
    if not record or type(record["reputation"]) ~= "table" then
        return false
    end

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

    if PEARL.DB:IsDisabled() then
        return
    end

    if not PEARL.DB:HasRecordFile(userid) then
        PEARL.error("Record not found for", userid)
        return
    end

    local rep = self:GetOf(userid)
    delta = math.min(delta, MAX_REP_EARN)
    local new_rep = math.floor(rep + delta)
    if limit then
        new_rep = math.max(new_rep, limit)
    end

    self:SetFor(userid, new_rep)

    return new_rep
end

-- Players are earning reputation from their own in-game actions and behaviour.
-- The more reputation they have the less they earn and vice versa.
-- This has no limits, so the reputation can go below zero which then causes the player to be banned.
function Reputation:EarnFor(userid, amount)
    local rep = self:GetOf(userid)

    local gained = math.max(rep - STARTING_REPUTATION, 0)
    local mult = REP_BASE / math.log(math.max(gained ^ REP_EARN_SCALE, 2))
    if amount < 0 then
        mult = NEGATIVE_REP_MULTIPLIER
    end

    self:DoDeltaTo(userid, amount * mult)
end

-- This is for giving specific amounts of reputation to a player.
-- This amount is not being changed by any multiplayer.
-- This can't go bellow the minimal player reputation so the player wont get banned this way.
function Reputation:GiveTo(userid, amount)
    return self:DoDeltaTo(userid, amount, BAD_REP_THRESHOLD)
end

function Reputation:SetTo(userid, value)
    return self:SetFieldFor(userid, "value", value)
end

function Reputation:InitializeFor(userid)
    local data = deepcopy(DEFAULT_REP_DATA)
    if PEARL.DB:SetField(userid, FIELD_NAME, data) then
        PEARL.EventProcessor:HandleEvent("onreputationchanged", userid, 0, data.value)
    end
end

--------------------------------------
-- [[ Return ]]
--------------------------------------

return Reputation
