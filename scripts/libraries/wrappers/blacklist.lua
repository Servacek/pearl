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

    NOTES:
        - TheNet:GetBlacklist() always creates a new table.
--]]

local PEARL = PEARL
local table = table
local TheNet = TheNet

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

            return true
        end
    end

    return false
end

function BlackList:AddPlayerByID(userid)
    return TheNet:Ban(userid)
end

--------------------------------
-- [[ Getters ]]
--------------------------------

--- @return table blacklist An array-like table of user tables.
function BlackList:Get()
    -- Returns always a new table
    return TheNet:GetBlacklist() or {}
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
            PEARL.info("\t"..i..". "..tostring(v.userid or v.netid).."")
        end
    end
end

--------------------------------

return BlackList
