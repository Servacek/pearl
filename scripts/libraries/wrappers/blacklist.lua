--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
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
local BlackList = {}

--------------------------------
-- [[ Setters ]]
--------------------------------

function BlackList:Set(blacklist)
    return TheNet:SetBlacklist(blacklist)
end

--- @param userid string Supports both Klei and Steam IDs.
--- @return boolean success Whether we were able to remove the given userid or not
function BlackList:RemovePlayerByID(userid)
    local blacklist = self:Get()
    for i, record in ipairs(blacklist) do
        if not record.empty and (record.userid == userid or record.netid == userid) then
            table.remove(blacklist, i)
            self:Set(blacklist)

            PEARL.EventProcessor:HandleEvent("clientunbanned", userid)

            return true
        end
    end

    return false
end

function BlackList:AddPlayerByID(id)
    return TheNet:Ban(id)
end

--------------------------------
-- [[ Getters ]]
--------------------------------

--- @return table blacklist An array-like table of user tables.
function BlackList:Get()
    return TheNet:GetBlacklist()
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

--- @param userid string Supports both Klei and Steam IDs.
function BlackList:GetPlayerByID(userid)
    for _, record in ipairs(self:Get()) do
        if not record.empty and (record.userid == userid or record.netid == userid) then
            return record
        end
    end
end

--- @param userid string Supports both Klei and Steam IDs.
--- @return boolean result Whether the given ID is on the blacklist or not.
function BlackList:Contains(userid)
    return self:GetPlayerByID(userid) ~= nil
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
-- [[ Return ]]
--------------------------------

return BlackList
