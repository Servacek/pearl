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
    Alternative to whitelist.txt.
--]]

local ClusterUserList = PEARL.loadlib("wrappers/models/clusteruserlist")

--------------------------------------
-- [[ Constants ]]
--------------------------------------

local ALLOWLIST_PATH = "../../allowlist.txt"

--------------------------------------
-- [[ Class Declaration ]]
--------------------------------------

--- @singleton
--- @class AllowList: ClusterUserList
local AllowList = ClusterUserList(ALLOWLIST_PATH)

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
