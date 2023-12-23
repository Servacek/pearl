--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--[[
    A wrapper class for the server's blacklist. Uses the low-level TheNet's functions
    for accessing the data. This is being added to the main mod table, so it's
    accessible basically from everywhere.

    This also fixes up some bugs with bad decoded files, since it uses patterns
    for precise parsing.

    NOTES:
        - TheNet:GetBlacklist() always creates a new table.
--]]

local ClusterUserList = PEARL.loadlib("clusteruserlist")

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

--- @type function, function
local _SetEngineList
BlackList:SetSaveFn(function() end) -- No explicit saving :/

-- Supports Steam ID and Klei ID
-- Fixes some errors when reading files with bad enconding.
BlackList:SetLoadFn(function(self)
    local blacklist = {}

    -- Even though this seems like an async function, it blocks.
    PEARL.ClusterPersistance:ForEachLineIn(self._path, function(line)
        local netid = line:match(STEAM_ID_PATTERN)
        local userid = line:match(KLEI_ID_PATTERN)
        if not (netid or userid) then
            return
        end

        self:AddLocal(userid)
        self:AddLocal(netid)

        -- We are saving only the IDs for now.
        blacklist[#blacklist+1] = {
            netid               = netid or "",
            userid              = userid or "",
            servername          = "",
            character           = "",
            timestamp           = "",
            serverdescription   = "",
        }
    end, self._ensure)

    if TheShard:IsMaster() then
        BlackList:SetEngineList(blacklist)
    end
end)
BlackList:SetAddFn(function(self, id, ...)
    -- These engine functions do only work on the Master shard.
    if TheShard:IsMaster() then
        BlackList:Ban(id, ...) -- Implicitly saves the whitelist.
    end
end)
BlackList:SetRemoveFn(function(self, id)
    -- These engine functions do only work on the Master shard.
    if TheShard:IsMaster() then
        BlackList:RemoveFromEngineList(id) -- Implicitly saves the whitelist.
    end
end)

--------------------------------
-- [[ Setters ]]
--------------------------------

--- @return table blacklist An array-like table of user tables.
function BlackList:SetEngineList(blacklist)
    return _SetEngineList(TheNet, blacklist)
end

--------------------------------
-- [[ Getters ]]
--------------------------------

--- @return table blacklist An array-like table of user tables.
function BlackList:GetEngineList()
    return TheNet:GetBlacklist()
end

--- Checks whether the given record belongs to the given ID.
--- @param record table<string, any>
--- @param id string? Identifier of the user (Steam ID, Klei ID)
function BlackList:IsRecordFor(record, id)
    return record and not record.empty and (record.userid == id or record.netid == id)
end

--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return table<string, any>? record, integer? index An array-like table of user tables.
function BlackList:GetEngineRecordByID(id)
    for i, record in ipairs(self:GetEngineList()) do
        if self:IsRecordFor(record, id) then
            return record, i
        end
    end
end

--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return boolean
function BlackList:HasBanRecord(id)
    return self:GetEngineRecordByID(id) ~= nil
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

--- Adds the given ID to the engine table.
--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return boolean success Whether the action was successfull or not.
function BlackList:Ban(id, seconds, reason, author)
    PEARL.debug("User", id, "was banned by", author or "[HOST]")

    if not self:HasBanRecord(id) then
        PEARL.EventProcessor:HandleEvent("clientbanned", id, seconds, reason, author)
    end

    PEARL.Ban(id, seconds)
    return true
end

--- Removes the given ID from the engine table.
--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return boolean success Whether we were able to remove the given userid or not
function BlackList:RemoveFromEngineList(id)
    local success = false
    local blacklist = self:GetEngineList()
    for i, record in ipairs(blacklist) do
        if self:IsRecordFor(record, id) then
            if table.remove(blacklist, i) ~= nil then
                self:SetEngineList(blacklist)

                PEARL.EventProcessor:HandleEvent("clientunbanned", id)

                success = true -- Continue to remove all occurrences
            end
        end
    end

    return success
end

--------------------------------
-- [[ Debugging ]]
--------------------------------

function BlackList:PrintDebugInfo()
    PEARL.info("SERVER BLACKLIST:")

    for i, v in ipairs(self:GetEngineList()) do
        if not v.empty then
            PEARL.info("\t"..i..". "..tostring(v.userid).." "..tostring(v.netid))
        end
    end
end

--------------------------------
-- [[ Handlers ]]
--------------------------------

_SetEngineList = PEARL.AddUserDataFunctionPreCall("SetBlacklist", function(self, blacklist)
    if type(blacklist) == "table" then
        BlackList:Clear()

        for _, record in ipairs(blacklist) do
            local id = record.userid or record.netid
            if id then
                BlackList:Add(id)
            end
        end
    end
end, TheNet)

--------------------------------
-- [[ Return ]]
--------------------------------

return BlackList
