--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local EMBEDS = require("utils/embeds")

--------------------------------------
-- [[ Constants ]]
--------------------------------------

local POST_COOLDOWN = 12 * 60 * 60

local LEADERBOARD_FILE_PATH = "leaderboard"

local MIN_GAINS_FOR_LEADERBOARDING = 25
local MIN_REP_FOR_LEADERBOARDING = 200
local LEADERBOARD_MAX_LEN = PEARL.CONSTS.LEADERBOARD_MAX_LEN

--------------------------------------
-- [[ Local Functions ]]
--------------------------------------

--- @param data table
--- @return table
local function CreateValidDataFrom(data)
    if type(data) ~= "table" then
        data = {}
    end

    -- Validate the provided table.
    data.players     = type(data.players) == "table" and data.players or {}
    data.records     = type(data.records) == "number" and data.records or 0
    data.timecreated = type(data.timecreated) == "number" and data.timecreated or os.time()
    data.changes     = type(data.changes) == "boolean" and data.changes or false
    data.dayleader   = type(data.dayleader) == "string" and data.dayleader or nil

    return data
end

--------------------------------------
-- [[ Sorters ]]
--------------------------------------

local function CompRepFields(name, uid1, uid2)
    return PEARL.PlayerDB:GetSubField(
        uid1, "reputation", name
    ) > PEARL.PlayerDB:GetSubField(uid2, "reputation", name)
end

local function CompByTotalRep(...)
    return CompRepFields("value", ...)
end

local function CompByMonthRepGains(...)
    return CompRepFields("monthgains", ...)
end

--------------------------------------
-- [[ Class Declaration ]]
--------------------------------------

--- @class Leaderboard
local Leaderboard

--- @param self Leaderboard
Leaderboard = Class(function(self, data)
    --- @type string
    self.type = Leaderboard.TYPE.ABSOLUTE
    --- @type table
    self.data = CreateValidDataFrom(data)

    self:Validate()

    assert(type(self.data) == "table" and not table.empty(self.data))
end)

--------------------------------------
-- [[ Static ]]
--------------------------------------

Leaderboard.TYPE = {
    ABSOLUTE = "absolute",
    MONTHLY  = "monthly",
}

Leaderboard.CONFIGURATION = {
    [Leaderboard.TYPE.ABSOLUTE] = {
        -- The number of players need for the leaderboard to show.
        min_records = LEADERBOARD_MAX_LEN,
        comp = CompByTotalRep,
        embed_pos = 1,
    },

    [Leaderboard.TYPE.MONTHLY] = {
        min_records = 3,
        comp = CompByMonthRepGains,
        embed_pos = 2,

        --- @TODO:
        check = function(userid)
            local monthgains = PEARL.Reputation:GetRepFieldOf(userid, "monthgains")
            if monthgains and monthgains >= MIN_GAINS_FOR_LEADERBOARDING then
                return true
            end

            return false
        end
}
}

function Leaderboard.CanAddPlayer(userid)
    local reputation = PEARL.Reputation:GetOf(userid) or 0
    if reputation < MIN_REP_FOR_LEADERBOARDING then
        return false
    end

    return not PEARL.ServerNetwork:IsClientBanned(userid) and
           not PEARL.ServerNetwork:IsAdmin(userid)
end

--------------------------------------
-- [[ Getters ]]
--------------------------------------

function Leaderboard:GetLeaderUserID()
    return self.data.players[1]
end

function Leaderboard:HasEnoughData()
    return #self.data.players >= Leaderboard.CONFIGURATION[self.type].min_records
end

function Leaderboard:HasPlayer(userid)
    return table.contains(self.data.players, userid)
end

function Leaderboard:GetPositionFor(userid)
    for i = 1, LEADERBOARD_MAX_LEN, 1 do
        if self.data.players[i] == userid then
            return i
        end
    end
end

function Leaderboard:GetData()
    return self.data
end

function Leaderboard:GetConfig()
    return Leaderboard.CONFIGURATION[self.type]
end

function Leaderboard:GetEmbedPosition()
    return self:GetConfig().embed_pos
end

function Leaderboard:GetEmbed()
    return EMBEDS.Leaderboard(self, self.type == Leaderboard.TYPE.MONTHLY)
end

--------------------------------------
-- [[ Setters ]]
--------------------------------------

function Leaderboard:SetData(data)
    self.data = data
end

function Leaderboard:SetType(type)
    if not table.contains(Leaderboard.TYPE, type) then
        return PEARL.error("Attempted to set an invalid leaderboard type!")
    end

    self.type = type
end

--------------------------------------
-- [[ Public Methods ]]
--------------------------------------

function Leaderboard:Validate()
    for i = #self.data.players, 1, -1 do
        if not self.CanAddPlayer(self.data.players[i]) then
            self:RemovePlayer(i)
        end
    end
end

function Leaderboard:InsertPlayer(i, userid)
    PEARL.debug("Leaderboard:InsertPlayer", i, userid, self.type)

    if self:HasPlayer(userid) then
        return print("ALREADY!") -- Player already in the leaderboard
    end

    self.data.players[i] = userid

    --- @TODO:
    -- We are counting the total number of records the leaderboard was built from.
    if type(self.data.records) == "number" then
        self.data.records = self.data.records + 1
    end

    self.data.changes = true

    return userid
end

function Leaderboard:RemovePlayer(i)
    PEARL.debug("Leaderboard:InsertPlayer", i, self.type)

    local userid = table.remove(self.data.players, i)
    if userid ~= nil then
        PEARL.info("User", userid, "removed from", self.type, "leaderboard...")

        self.data.changes = true
    end

    return userid
end

function Leaderboard:RemovePlayerByID(userid)
    return self:RemovePlayer(self:GetPositionFor(userid))
end

function Leaderboard:RemoveAllPlayers()
    table.iclear(self.data.players)
end

function Leaderboard:ClearData()
    return table.clear(self.data)
end

function Leaderboard:ResetData()
    PEARL.debug("Leaderboard:Reset()")

    self.data = CreateValidDataFrom(self:ClearData())
end

--------------------------------------
-- [[ Handlers ]]
--------------------------------------

function Leaderboard:OnReputationChanged(userid)
    local leaders = self.data.players
    local init_pos = self:GetPositionFor(userid)

    local config = self:GetConfig()
    local comp = config.comp or CompByTotalRep
    local last_index = math.min(#leaders + 1, LEADERBOARD_MAX_LEN)
    local last_userid = leaders[last_index]
    if not init_pos and (not last_userid or comp(userid, last_userid)) then
        self:InsertPlayer(last_index, userid)
    end

    table.sort(leaders, comp)

    -- If our position in the leaderboard has changed, make it visible.
    return self:GetPositionFor(userid) ~= init_pos
end

--------------------------------------
-- [[ Return ]]
--------------------------------------

return Leaderboard
