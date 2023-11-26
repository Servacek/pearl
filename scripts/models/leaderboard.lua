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
    data.dayleader   = type(data.dayleader) == "string" and data.dayleader or nil

    return data
end

--------------------------------------
-- [[ Class Declaration ]]
--------------------------------------

--- @class Leaderboard
local Leaderboard

--- @param self Leaderboard
Leaderboard = Class(function(self, data)
    --- @type boolean
    self.loaded = type(data) == "table" and not table.empty(data)
    --- @type boolean
    self.changed = not self.loaded

    --- @type string
    self.type = Leaderboard.TYPE.ABSOLUTE
    --- @type integer
    self.minplayers = 1
    --- @type integer
    self.maxplayers = PEARL.CONSTS.LEADERBOARD_MAX_LEN
    --- @type table
    self.data = CreateValidDataFrom(data)

    --- @type function?
    self.sortfn = nil
    --- @type function?
    self.checkfn = nil

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

--------------------------------------
-- [[ Getters ]]
--------------------------------------

function Leaderboard:IsValid(userid)
    return not self.checkfn or self.checkfn(userid)
end

function Leaderboard:HasAnyUnsavedChanges()
    return self.changed == true
end

function Leaderboard:GetIndex()
    return self.index
end

function Leaderboard:GetMinRecords()
    return self.minplayers
end

function Leaderboard:GetLeaderUserID()
    return self.data.players[1]
end

function Leaderboard:HasEnoughPlayers()
    return #self.data.players >= self.minplayers
end

function Leaderboard:HasPlayer(userid)
    return table.contains(self.data.players, userid)
end

function Leaderboard:GetPositionFor(userid)
    return table.index(self.data.players, userid)
end

function Leaderboard:GetData()
    return self.data
end

function Leaderboard:GetEmbed()
    return EMBEDS.Leaderboard(self, self.type == Leaderboard.TYPE.MONTHLY)
end

--------------------------------------
-- [[ Setters ]]
--------------------------------------

function Leaderboard:SetDayLeaderUserID(userid)
    if self.data.dayleader ~= userid then
        self.data.dayleader = userid
        self.changed = true
    end
end

function Leaderboard:SetIndex(index)
    self.index = index
end

function Leaderboard:SetCheckFn(checkfn)
    self.checkfn = checkfn
end

function Leaderboard:SetSortFn(sortfn)
    self.sortfn = sortfn
end

function Leaderboard:SetData(data)
    self.data = data
    self.changed = true
end

function Leaderboard:SetMinPlayers(count)
    self.minplayers = count
end

function Leaderboard:SetMaxPlayers(count)
    self.maxplayers = count
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
        if not self:IsValid(self.data.players[i]) then
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
    self.changed = true

    --- @TODO:
    -- We are counting the total number of records the leaderboard was built from.
    if type(self.data.records) == "number" then
        self.data.records = self.data.records + 1
    end

    return userid
end

function Leaderboard:RemovePlayer(i)
    PEARL.debug("Leaderboard:RemovePlayer", i, self.type)

    local userid = table.remove(self.data.players, i)
    if userid ~= nil then
        PEARL.info("User", userid, "removed from", self.type, "leaderboard...")

        self.data.changed = true
    end

    return userid
end

--- @param userid string The userid of the player to remove.
--- @return string? userid The userid of the removed player, if any.
function Leaderboard:RemovePlayerByID(userid)
    return self:RemovePlayer(self:GetPositionFor(userid))
end

function Leaderboard:RemoveAllPlayers()
    if not table.empty(self.data.players) then
        table.iclear(self.data.players)
        self.changed = true
    end
end

function Leaderboard:ClearData()
    if not table.empty(self.data) then
        table.clear(self.data)
        self.changed = true
    end

    return self.data
end

function Leaderboard:Reset()
    PEARL.debug("Leaderboard:Reset()")

    self:SetData(CreateValidDataFrom(self:ClearData()))
end

--------------------------------------
-- [[ Handlers ]]
--------------------------------------

function Leaderboard:OnSave()
    self.changed = false
    return self:GetData()
end

function Leaderboard:OnReputationChanged(userid)
    -- Reputation has changed, verify that the player is still allowed to be on the leaderboard.
    if not self:IsValid(userid) then
        PEARL.debug("Checkfn failed! Removing player.")
        self:RemovePlayerByID(userid)
        return
    end

    local players = self.data.players
    local init_pos = self:GetPositionFor(userid)

    local comp = type(self.sortfn) == "function" and self.sortfn or nil
    local last_index = math.min(#players + 1, self.maxplayers)
    local last_userid = players[last_index]
    if not init_pos and (not last_userid or (comp and comp(userid, last_userid))) then
        self:InsertPlayer(last_index, userid)

        table.sort(players, comp)
    end

    -- If our position in the leaderboard has changed, make it visible.
    return self:GetPositionFor(userid) ~= init_pos
end

--------------------------------------
-- [[ Return ]]
--------------------------------------

return Leaderboard
