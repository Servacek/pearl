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
    Wrapper for the built-in whitelisting system.

    The engine owns the whitelist, so this wrapper deliberately does not access
    whitelist.txt. The engine exposes membership and mutation, but not enumeration.
]]

local PersistentUserIDList = PEARL.loadlib("wrappers/models/useridlist")

--------------------------------------
-- [[ Constants ]]
--------------------------------------

--------------------------------------
-- [[ Class Declaration ]]
--------------------------------------

--- @singleton
--- @class Whitelist: PersistentUserIDList
local WhiteList = PersistentUserIDList("engine:whitelist")

--- @type function, function
local _AddToEngineList, _RemoveFromEngineList, _IsWhiteListed
WhiteList:SetSaveFn(function() end) -- No explicit saving :/
WhiteList:SetLoadFn(function() end)

-- This is handled by the game itself.
WhiteList.Load = function() end
WhiteList.Save = function() end

WhiteList:SetAddFn(function(self, userid)
    if WhiteList:GetMode() == WhiteList.MODE.STRICT and PEARL.ServerNetwork:IsClientConnectedAny(userid) then
        TheNet:Kick(userid)
    end

    -- These engine functions do only work on the Master shard.
    if TheShard:IsMaster() then
        _AddToEngineList(TheNet, userid) -- Implicitly saves the whitelist.
    end
end)
WhiteList:SetRemoveFn(function(self, userid)
    -- These engine functions do only work on the Master shard.
    if TheShard:IsMaster() then
        _RemoveFromEngineList(TheNet, userid) -- Implicitly saves the whitelist.
    end
end)

--------------------------------------
-- [[ Static ]]
--------------------------------------

WhiteList.MODE = {
    DISABLED = 0,
    DEFAULT = 1,
    STRICT = 2, -- Only players on the list will be able to join
}

--------------------------------------
-- [[ Private Variables ]]
--------------------------------------

local _mode = WhiteList.MODE.DEFAULT

--------------------------------------
-- [[ Setters ]]
--------------------------------------

function WhiteList:SetMode(mode)
    _mode = mode
end

--------------------------------------
-- [[ Getters ]]
--------------------------------------

function WhiteList:GetMode()
    return _mode
end

function WhiteList:Contains(userid)
    return self._ids[userid] == true or _IsWhiteListed(TheNet, userid) == true
end

--------------------------------------
-- [[ Overrides ]]
--------------------------------------
-- The original version is very poorely implemented so we are using our own.
-- They do not work for secondary shards and also do not propagate the changes.
--
-- Note: These functions expect saving!

_IsWhiteListed = TheNet.IsWhiteListed

PEARL.OverrideUserdataValue("IsWhiteListed", function(self, userid)
    return WhiteList:Contains(userid)
end, TheNet)

_AddToEngineList = PEARL.OverrideUserdataValue("AddToWhiteList", function(self, userid)
    return WhiteList:Add(userid)
end, TheNet)

_RemoveFromEngineList = PEARL.OverrideUserdataValue("RemoveFromWhiteList", function(self, userid)
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
