--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @TODO: Would be nice to have actually real temporary bans:
--- https://forums.kleientertainment.com/forums/topic/68270-game-update-181652/?do=findComment&comment=785408


--[[
    A wrapper class for the server's blacklist. Uses the low-level TheNet's functions
    for accessing the data. This is being added to the main mod table, so it's
    accessible basically from everywhere.

    This also fixes up some bugs with bad decoded files, since it uses patterns
    for precise parsing.
--]]

local ClusterUserList = PEARL.loadfile("libs/wrappers/models/clusteruserlist")

--------------------------------
-- [[ Constants ]]
--------------------------------

local BLACKLIST_PATH    = "../../blocklist.txt"

local KLEI_ID_PATTERN   = PEARL.CONSTS.KLEI_ID_PATTERN
local STEAM_ID_PATTERN  = PEARL.CONSTS.STEAM_ID_PATTERN

--------------------------------
-- [[ Initialization ]]
--------------------------------

--- @singleton
--- @class BlackList: ClusterUserList
local BlackList = ClusterUserList(BLACKLIST_PATH)

BlackList:SetSaveFn(function() end) -- No explicit saving :/

-- Supports Steam ID and Klei ID
-- Fixes some errors when reading files with bad enconding.
BlackList:SetLoadFn(function(self)
    local blacklist = {}

    -- This is the only way how to add userids on a list without
    -- Even though this seems like an async function, it blocks.
    PEARL.ClusterPersistence:ForEachLineIn(self._path, function(line)
        local netid = line:match(STEAM_ID_PATTERN)
        local userid = line:match(KLEI_ID_PATTERN)
        if not (netid or userid) then
            return PEARL.warn("Removing invalid line", string.raw(line))
        end

        blacklist[#blacklist+1] = { -- We are saving only the IDs for now.
            netid               = netid or "",
            userid              = userid or "",
            servername          = "",
            character           = "",
            timestamp           = "",
            serverdescription   = "",
        }
    end, self._ensure)

    BlackList:Set(blacklist)
end)

--------------------------------
-- [[ Setters ]]
--------------------------------

--- @return table<table<string, string>> blacklist An array-like table of user ban record tables.
function BlackList:Set(blacklist)
    return TheNet:SetBlacklist(blacklist)
end

--------------------------------
-- [[ Getters ]]
--------------------------------

--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return boolean
function BlackList:Contains(id)
    return self:GetBanRecordByID(id) ~= nil
end

--- Creates a new table with all the records every time called.
--- @return table<table<string, string>> blacklist An array-like table of user ban record tables.
function BlackList:Get()
    return TheNet:GetBlacklist()
end

--- Checks whether the given record belongs to the given ID.
--- @param record table<string, string> An user's ban record table.
--- @param id string? Identifier of the user (Steam ID, Klei ID)
function BlackList:IsBanRecordForUser(record, id)
    return record and not record.empty and (record.userid == id or record.netid == id)
end

--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return table<string, string>? record, integer? index An array-like table of user tables.
function BlackList:GetBanRecordByID(id)
    for i, record in ipairs(self:Get()) do
        if self:IsBanRecordForUser(record, id) then
            return record, i
        end
    end
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

--- We do not push any events here because there are other ways how a player
--- can be added to this list not mentioned here.
--- Adds the given ID to the engine table.
--- @param userid string? Klei ID
--- @return boolean success Whether the action was successfull or not.
function BlackList:AddLocal(userid)
    PEARL.debug("BlackList:AddToEngineList")

    if not userid or self:Contains(userid) then
        return false -- Record already exists
    end

    TheNet:Ban(userid)

    return true
end

--- Removes the given ID from the engine table.
--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return boolean success Whether we were able to remove the given userid or not
function BlackList:RemoveLocal(id)
    PEARL.debug("BlackList:RemoveFromEngineList", id)

    local success = false
    local blacklist = self:Get()
    for i, record in ipairs(blacklist) do
        if self:IsBanRecordForUser(record, id) and table.remove(blacklist, i) ~= nil then
            success = true -- Continue to remove all occurrences
        end
    end

    if success then
        self:Set(blacklist)
        PEARL.EventProcessor:HandleEvent("clientunbanned", id)
    end

    return success
end

function BlackList:Clear()
    self:Set({})
end

--------------------------------
-- [[ Debugging ]]
--------------------------------

function BlackList:DisplayDebugInfo()
    PEARL.info("SERVER BLACKLIST:")

    for i, v in ipairs(self:Get()) do
        if not v.empty then
            PEARL.info("\t"..i..". "..tostring(v.userid).." "..tostring(v.netid))
        end
    end
end

--------------------------------
-- [[ Return ]]
--------------------------------

return BlackList
