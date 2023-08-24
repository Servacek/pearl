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
    Alternative to whitelist.txt.
]]

if TheNet:GetIsClient() or not TheNet:IsDedicated() then
    return
end

--------------------------------------
-- [[ Contants ]]
--------------------------------------

local ALLOWLIST_PATH = "../../allowlist.txt"

--------------------------------------
-- [[ Initialization ]]
--------------------------------------

--- @class AllowList
local AllowList = {
    _userids = {},

    _enabled = false,
}

--------------------------------------
-- [[ Member Functions ]]
--------------------------------------

function AllowList:Toggle()
    self._enabled = not self._enabled

    return self._enabled
end

function AllowList:SetIsEnabled(enabled)
    self._enabled = enabled
end

function AllowList:IsEnabled()
    return self._enabled
end

function AllowList:Add(userid)
    if userid and not self._userids[userid] then
        self._userids[userid] = true
    end
end

function AllowList:Remove(userid)
    if self._userids[userid] then
        self._userids[userid] = nil
    end
end

function AllowList:Contains(userid)
    return self._userids[userid] or false
end

function AllowList:Load()
    PEARL.GetPersistentStringByLines(ALLOWLIST_PATH, function(line)
        self:Add(line:strip())
    end, true)
end

-- We are being saved manually for now.
function AllowList:Save()
    if not PEARL.EnsurePersistentString(ALLOWLIST_PATH) then
        PEARL.error("Couldn't create the allowlist file!")
        return false
    end

    return PEARL.SetPersistentString(ALLOWLIST_PATH, self:ToString())
end

function AllowList:ToString()
    local string = ""
    for userid, _ in pairs(self._userids) do
        -- Start with a new line
        string = string.."\n"..userid
    end

    return string
end

function AllowList:Clear()
    for userid, _ in pairs(self._userids) do
        self._userids[userid] = nil
    end
end

function AllowList:Reload()
    self:Clear()
    self:Load()
end

--------------------------------------
-- [[ Event Handlers ]]
--------------------------------------

local function OnClientBanned(userid)
    -- Make sure that user looses all the priviliges after being banned and unbanned.
    AllowList:Remove(userid)
end

--------------------------------------
-- [[ Setup ]]
--------------------------------------

-- Master does handle all the connections.
if TheShard:IsMaster() and PEARL.ServerNetwork then
    PEARL.ServerNetwork:AddJoinServerFilter(function(userid)
        -- IsEnabled return value can be changed during runtime!
        -- TheNet:GetUserID returns the owner's ID on dedicated servers.
        if AllowList:IsEnabled() and not (
            PEARL.AdminList:Contains(userid) or
            userid == TheNet:GetUserID()
        ) and not AllowList:Contains(userid) then
            PEARL.info("Client", userid, "not allowlisted.")
            return false, "ID_DST_SLOT_RESERVATION"
        end
    end)

    PEARL.EventProcessor:AddSafeEventHandler("clientbanned", OnClientBanned)
end

--------------------------------------
-- [[ Return ]]
--------------------------------------

return AllowList
