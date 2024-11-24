--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local EMBEDS = PEARL.loadfile("utils/embeds")

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
    data.timecreated = type(data.timecreated) == "number" and data.timecreated or os.time()
    data.dayleader   = type(data.dayleader) == "string" and data.dayleader or nil
    data.updated     = type(data.updated) == "boolean" and data.updated or false

    return data
end

--------------------------------------
-- [[ Sorters ]]
--------------------------------------

local function CompRepFields(name, uid1, uid2)
    return PEARL.Reputation:GetFieldOf(uid1, name) > PEARL.Reputation:GetFieldOf(uid2, name)
end

local function CompByTotalRep(...)
    return CompRepFields(PEARL.Reputation.FIELD.VALUE, ...)
end

local function CompByMonthRepGains(...)
    return CompRepFields(PEARL.Reputation.FIELD.MONTHGAINS, ...)
end

--------------------------------------
-- [[ Class Declaration ]]
--------------------------------------

--- @class Leaderboard
local Leaderboard

--- @param self Leaderboard
Leaderboard = Class(function(self, typ, data)
    assert(typ == nil or type(typ) == "string", "Invalid leaderboard type provided!")
    assert(data == nil or type(data) == "table", "Invalid data provided!")

    --- @type boolean
    self.loaded = type(data) == "table" and table.empty(data) == false or false

    --- @type boolean
    self.saved = self.loaded == true
    self.updating = false

    --- @type string
    self.type = typ or Leaderboard.TYPE.ABSOLUTE
    --- @type integer
    self.minplayers = 1
    --- @type integer
    self.displaycount = PEARL.CONSTS.LEADERBOARD_DISPLAY_COUNT
    --- @type table
    self.data = CreateValidDataFrom(data)
    self.index = 1

    --- @type function
    self.sortfn = Leaderboard.COMP[self.type]

    if self.loaded then
        self:OnLoaded()
    end
end)

--------------------------------------
-- [[ Static ]]
--------------------------------------

Leaderboard.TYPE = {
    ABSOLUTE = PEARL.CONFIG.LEADERBOARD.TYPES.ABSOLUTE == true and "absolute" or nil,
    MONTHLY  = PEARL.CONFIG.LEADERBOARD.TYPES.MONTHLY == true and "monthly" or nil,
}

Leaderboard.COMP = {
    [Leaderboard.TYPE.ABSOLUTE]   = CompByTotalRep,
    [Leaderboard.TYPE.MONTHLY]    = CompByMonthRepGains,
}

--------------------------------------
-- [[ Getters ]]
--------------------------------------

function Leaderboard:HasAnyUnsavedChanges()
    return self.saved == false
end

function Leaderboard:GetIndex()
    return self.index
end

function Leaderboard:GetPlayers()
    return self.data.players
end

function Leaderboard:GetPlayerOnPosition(position)
    return self.data.players[position]
end

function Leaderboard:GetLeaderUserID()
    return self.data.players[1]
end

function Leaderboard:IsUpdatingUI()
    return self.updating == true
end

function Leaderboard:IsUIUpToDate()
    return self.data.updated == true
end

function Leaderboard:HasEnoughPlayers()
    return #self.data.players >= self.minplayers
end

function Leaderboard:HasPlayer(userid)
    return table.contains(self.data.players, userid)
end

--- @return integer? position
function Leaderboard:GetPositionFor(userid)
    return table.index(self.data.players, userid)
end

--- @return table
function Leaderboard:GetData()
    return self.data
end

function Leaderboard:IsPlayerVisible(userid)
    return self:IsPositionVisible(self:GetPositionFor(userid)) or userid == self.data.dayleader
end

function Leaderboard:IsPositionVisible(position)
    return self:HasEnoughPlayers() and position and position <= self:GetDisplayCount()
end

function Leaderboard:GetEmbed(archived)
    if archived == true then
        return EMBEDS.LeaderboardArchived()
    end

    return EMBEDS.Leaderboard(self, self.type == Leaderboard.TYPE.MONTHLY)
end

function Leaderboard:GetLength()
    return #self.data.players
end

function Leaderboard:GetDisplayCount()
    return self.displaycount
end

--------------------------------------
-- [[ Setters ]]
--------------------------------------

function Leaderboard:SetDayLeaderUserID(userid)
    if self.data.dayleader ~= userid then
        self.data.dayleader = userid
        self:OnChange(true)
    end
end

function Leaderboard:SetIndex(index)
    self.index = index
end

--- @param data table
function Leaderboard:SetData(data)
    self.data = data
    self:OnChange(true)
end

function Leaderboard:SetMinPlayers(count)
    if self.minplayers ~= count then
        local had_enough = self:HasEnoughPlayers()
        self.minplayers = count
        if had_enough ~= self:HasEnoughPlayers() then
            self:OnChange(true)
        end
    end
end

function Leaderboard:SetDisplayCount(count)
    if self.displaycount ~= count then
        self.displaycount = count
        self:OnChange(true)
    end
end

function Leaderboard:SetType(type)
    if not table.contains(Leaderboard.TYPE, type) then
        return PEARL.error("Attempted to set an invalid leaderboard type!")
    end

    if self.type ~= type then
        self.type = type
        self:OnChange(true)
    end
end

--------------------------------------
-- [[ Public Methods ]]
--------------------------------------

--- @param userid string The userid of the player to add.
--- @return integer? position The position the player was added to.
function Leaderboard:AddPlayer(userid)
    PEARL.debug("Leaderboard:AddPlayer", userid, self.type)

    if self:HasPlayer(userid) then
        return PEARL.debug("ALREADY!") -- Player already in the leaderboard
    end

    local position = table.insort(self.data.players, userid, self.sortfn)
    local visible = self:IsPositionVisible(position)
    self:OnChange(visible)

    return position
end

function Leaderboard:UpdatePlayerPosition(position)
    PEARL.debug("Leaderboard:UpdatePlayerPosition", position)

    local new_position = table.reorder(self.data.players, position, self.sortfn)
    if new_position ~= position then -- If the position has actually changed.
        self:OnChange(self:IsPositionVisible(position) or self:IsPositionVisible(new_position))
    end
end

--- @param position integer
--- @return string userid The ID of the removed player.
function Leaderboard:Remove(position)
    PEARL.debug("Leaderboard:RemovePlayer", position, self.type)

    -- Use table.remove so the hole is fixed.
    local visible = self:IsPositionVisible(position)
    local userid = table.remove(self.data.players, position)
    if userid ~= nil then
        PEARL.info("User", userid, "removed from", self.type, "leaderboard...")
        self:OnChange(visible)
    end

    return userid
end

--- @param userid string The userid of the player to remove.
--- @return integer? position The position the player was removed from.
function Leaderboard:RemovePlayer(userid)
    local position = self:GetPositionFor(userid)
    if self:Remove(position) then
        return position
    end
end

function Leaderboard:RemoveAllPlayers()
    if not table.empty(self.data.players) then
        table.iclear(self.data.players)
        self:OnChange(true)
    end
end

function Leaderboard:ClearData()
    if not table.empty(self.data) then
        table.clear(self.data)
        self:OnChange(true)
    end

    return self.data
end

function Leaderboard:Reset()
    PEARL.debug("Leaderboard:Reset()")

    self:SetData(CreateValidDataFrom(self:ClearData()))
    self:OnChange(true)
end

function Leaderboard:Resort()
    table.sort(self.data.players, self.sortfn)
    self:OnChange(true)
end

function Leaderboard:Validate()
    -- Make sure that all players have a valid record file.
    for i, userid in pairs(self.data.players) do
        if not PEARL.DB:HasRecordFile(userid) then
            PEARL.info("Removing player", userid, "from the leaderboard for not having a valid record file!")

            self:Remove(i)
        end
    end
end

function Leaderboard:ToString()
    local abs = self.type == Leaderboard.TYPE.ABSOLUTE
    local FDS = STRINGS.PEARL.EMBEDS.LEADERBOARD.FD_NAMES
    local str = STRINGS.PEARL.EMBEDS.LEADERBOARD["TITLE_"..(abs and "ABS" or "CUR")]
    if not self:HasEnoughPlayers() then
        return str.."\n"..STRINGS.PEARL.EMBEDS.LEADERBOARD.NOT_ENOUGH_DATA
    end

    local names = table.map(self.data.players, function(userid)
        return PEARL.DB:GetField(userid, "username", userid)
    end)
    local maxsize = PEARL.GetMaxStringSize(names)
    str = str.."\n"..FDS.INDEX_COL.."\t"..FDS.NAME_COL.."\t\t"..FDS.REP_COL
    for place, userid in ipairs(self.data.players) do
        local rep = PEARL.Reputation:GetOf(userid)
        local name = names[place]
        local spacing2 = string.rep(" ", maxsize - string.utf8len(name) + 3).."\t"
        str = str.."\n"..place.."\t"..name..spacing2..tostring(rep)
    end

    return str
end

--------------------------------------
-- [[ Handlers ]]
--------------------------------------

function Leaderboard:OnChange(visible)
    self.saved = false

    PEARL.EventProcessor:HandleEvent("leaderboardchanged", self, visible)

    if visible == true then
        self.updating = false
        self.data.updated = false
    end
end

--- Every leaderboard has to manage it's own "updating" state since the changes are individual
--- as well. In case a change happens during the leaderboard being updated, the "updated" flag
--- won't be falsely overriden.
function Leaderboard:OnUpdateStart()
    PEARL.debug("OnUpdateStart", self.updating)

    self.updating = true
end

function Leaderboard:OnUpdateDone()
    PEARL.debug("OnUpdateDone", self.updating, self.data.updated)

    if self:IsUpdatingUI() then
        self.updating = false
        self.data.updated = true

        self:OnChange(false)
    end
end

function Leaderboard:OnLoaded()
    PEARL.debug("Leaderboard:OnLoaded")

    self:Validate()
end

--- @return table
function Leaderboard:OnSave()
    self.saved = true

    return self:GetData()
end

function Leaderboard:OnReputationChanged(userid)
    PEARL.debug("Leaderboard:OnReputationChanged", userid)

    local position = self:GetPositionFor(userid)
    if position then
        self:UpdatePlayerPosition(position)
        return
    end

    self:AddPlayer(userid)
end

--------------------------------------
-- [[ Return ]]
--------------------------------------

return Leaderboard
