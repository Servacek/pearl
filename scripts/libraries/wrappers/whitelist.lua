--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local math = math
local PEARL = PEARL

--------------------------------------
-- [[ Constants ]]
--------------------------------------

local WHITELIST_PATH = "../../whitelist.txt"

--------------------------------------
-- [[ Initialization ]]
--------------------------------------

--- @class Whitelist
local WhiteList = {
    _userids = {},

    MODE = {
        DISABLED = 0,
        DEFAULT = 1,
        STRICT = 2, -- Only players on the list will be able to join
    }
}

--------------------------------------
-- [[ Private Variables ]]
--------------------------------------

local _AddToWhiteList, _RemoveFromWhiteList, _IsWhiteListed

local _mode = WhiteList.MODE.DEFAULT

--------------------------------------
-- [[ Setters ]]
--------------------------------------

function WhiteList:Add(userid, broadcasted)
    if userid ~= nil and self._userids[userid] ~= true then
        PEARL.debug("WhiteList:Add", userid, broadcasted)

        self._userids[userid] = true
        if TheShard:IsMaster() then
            -- Update the engines table
            _AddToWhiteList(TheNet, userid)
        end

        if not broadcasted then
            PEARL.BroadcastRPCToAllShards(PEARL.RPC.AddToWhiteList, userid)
        end
    end
end

function WhiteList:Remove(userid, broadcasted)
    if self._userids[userid] ~= nil then
        PEARL.debug("WhiteList:Remove", userid, broadcasted)

        self._userids[userid] = nil
        if TheShard:IsMaster() then
            -- Update the engines table
            _RemoveFromWhiteList(TheNet, userid)
        end

        if not broadcasted then
            PEARL.BroadcastRPCToAllShards(PEARL.RPC.RemoveFromWhiteList, userid)
        end
    end
end

function WhiteList:SetMode(mode)
    _mode = mode
end

function WhiteList:GetMode()
    return _mode
end

--------------------------------------
-- [[ Getters ]]
--------------------------------------

function WhiteList:Contains(userid)
    return self._userids[userid] == true
end

--------------------------------------
-- [[ Public Functions ]]
--------------------------------------

function WhiteList:Load()
    if not PEARL.ClusterPersistance:FileExists(WHITELIST_PATH) then
        return PEARL.info("whitelist.txt not found -> skipping loading proccess...")
    end

    local lines = PEARL.ClusterPersistance:GetAllFileLines(WHITELIST_PATH, false, true)
    for _, userid in ipairs(lines) do
        self._userids[userid] = true
    end

    if _mode == WhiteList.MODE.STRICT then
        self:SyncReservedWithSlots()
    end
end

--------------------------------------
-- [[ RPCs ]]
--------------------------------------

PEARL.AddShardRPCHandler("AddToWhiteList", function(shardid, userid)
    WhiteList:Add(userid, true)
end)

PEARL.AddShardRPCHandler("RemoveFromWhiteList", function(shardid, userid)
    WhiteList:Remove(userid, true)
end)

--------------------------------------
-- [[ Overrides ]]
--------------------------------------
-- The original version is very poorely implemented so we are using our own.
-- They do not work for secondary shards and also do not propagate the changes.
--
-- Note: These functions expect saving!

_IsWhiteListed = PEARL.OverrideUserdataValue("IsWhiteListed", function(self, userid)
    return WhiteList:Contains(userid)
end, TheNet)

_AddToWhiteList = PEARL.OverrideUserdataValue("AddToWhiteList", function(self, userid)
    return WhiteList:Add(userid)
end, TheNet)

_RemoveFromWhiteList = PEARL.OverrideUserdataValue("RemoveFromWhiteList", function(self, userid)
    return WhiteList:Remove(userid)
end, TheNet)

--------------------------------------
-- [[ Filters  ]]
--------------------------------------

PEARL.ServerNetwork:AddJoinServerFilter(function(userid)
    if WhiteList:GetMode() == WhiteList.MODE.STRICT then
        return WhiteList:Contains(userid)
    end
end)

--------------------------------------
-- [[ Return ]]
--------------------------------------

return WhiteList
