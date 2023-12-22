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

--- @TODO: We probably want this to be synced between shards.

local PEARL = PEARL
local table = table
local TheNet = TheNet

--------------------------------
-- [[ Contants ]]
--------------------------------

local BLACKLIST_PATH = "../../blocklist.txt"

local KLEI_ID_PATTERN = "KU_"..string.rep("[%d%a%p]", 8)
local STEAM_ID_PATTERN = string.rep("%d", 17)

--------------------------------
-- [[ Initialization ]]
--------------------------------

--- @class BlackList
local BlackList = {
    --- @type table<string, boolean?>
    _userids = {},
}

--------------------------------
-- [[ Setters ]]
--------------------------------

function BlackList:Set(blacklist)
    return TheNet:SetBlacklist(blacklist)
end

--------------------------------
-- [[ Getters ]]
--------------------------------

--- @return table blacklist An array-like table of user tables.
function BlackList:Get()
    return TheNet:GetBlacklist()
end

--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return table<string, any>? record, integer? index An array-like table of user tables.
function BlackList:GetPlayerByID(id)
    for i, record in ipairs(self:Get()) do
        if not record.empty and (record.userid == id or record.netid == id) then
            return record, i
        end
    end
end

--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return boolean result Whether the given ID is on the blacklist or not.
function BlackList:Contains(id)
    return self._userids[id] == true or self:GetPlayerByID(id) ~= nil
end

--------------------------------
-- [[ Public Methods ]]
--------------------------------

--- Adds the given ID from the local and networked table.
--- If the user is playing on the server, a ban popup will be shown as well.
--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return boolean success Whether the ID was added or not.
function BlackList:Add(id)
    TheNet:Ban(id)

    return self:AddLocal(id)
end

--- Adds the given ID to the local table.
--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return boolean success Whether the ID was added or not.
function BlackList:AddLocal(id)
    if type(id) == "string" and self._userids[id] == nil then
        self._userids[id] = true
        return true
    end

    return false
end

--- Removes the given ID from the local and networked table.
--- @param id string? Identifier of the user (Steam ID, Klei ID)
--- @return boolean success Whether we were able to remove the given userid or not
function BlackList:Remove(id)
    local success = false
    local blacklist = self:Get()
    for i, record in ipairs(blacklist) do
        if not record.empty and (record.userid == id or record.netid == id) then
            if table.remove(blacklist, i) ~= nil then
                self:Set(blacklist)

                PEARL.EventProcessor:HandleEvent("clientunbanned", id)

                success = true -- Remove all occurrences
            end
        end
    end

    self:RemoveLocal(id)
    return success
end

--- Removes the given ID from the local table.
--- @param id string? Identifier of the user (Steam ID, Klei ID)
function BlackList:RemoveLocal(id)
    if type(id) == "string" and self._userids[id] ~= nil then
        self._userids[id] = nil

        return true
    end

    return false
end

-- Supports Steam ID and Klei ID
-- Fixes some errors when reading files with bad enconding.
function BlackList:Load()
    local blocklist = {}

    -- Even though this seems like an async function, it blocks.
    PEARL.ClusterPersistance:ForEachLineIn(BLACKLIST_PATH, function(line)
        local netid = line:match(STEAM_ID_PATTERN)
        local userid = line:match(KLEI_ID_PATTERN)

        if not (netid or userid) then
            return
        end

        self:AddLocal(userid)
        self:AddLocal(netid)


        -- We are saving only the IDs for now.
        blocklist[#blocklist+1] = {
            netid               = netid or "",
            userid              = userid or "",
            servername          = "",
            character           = "",
            timestamp           = "",
            serverdescription   = "",
        }
    end, true)

    self:Set(blocklist)
end

--------------------------------
-- [[ Debugging ]]
--------------------------------

function BlackList:PrintDebugInfo()
    PEARL.info("SERVER BLACKLIST:")

    for i, v in ipairs(self:Get()) do
        if not v.empty then
            PEARL.info("\t"..i..". "..tostring(v.userid).." "..tostring(v.netid))
        end
    end
end

--------------------------------
-- [[ Handlers ]]
--------------------------------

PEARL.AddUserDataFunctionPreCall("SetBlacklist", function(self, userid)
    return WhiteList:Add(userid)
end, TheNet)

--------------------------------
-- [[ Overrides ]]
--------------------------------

_RemoveFromWhiteList = PEARL.OverrideUserdataValue("GetBlacklist", function(self)
    return WhiteList:Remove(id)
end, TheNet)


--------------------------------
-- [[ RPCs ]]
--------------------------------

PEARL.AddShardRPCHandler("BlackListModified", function(shardid, userid)
    WhiteList:Remove(userid, true)
end)

PEARL.AddShardRPCHandler("ClientBanned", function(shardid, userid)
    WhiteList:Remove(userid, true)
end)

--------------------------------
-- [[ Return ]]
--------------------------------

return BlackList
