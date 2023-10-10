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

local POST_COOLDOWN = 12 * 60 * 60

local LEADERBOARD_FILE_PATH = "leaderboard"

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

    return data
end

--------------------------------------
-- [[ Class Declaration ]]
--------------------------------------

--- @class Leaderboard
local Leaderboard
Leaderboard = Class(function(self, data)
    self.type = Leaderboard.TYPE.ABSOLUTE
    --- @type table
    self.data = CreateValidDataFrom(data)

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
-- [[ Return ]]
--------------------------------------

return Leaderboard
