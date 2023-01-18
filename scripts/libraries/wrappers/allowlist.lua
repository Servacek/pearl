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

local ALLOWLIST_PATH = PEARL.ROOTDIR..""..PEARL.DATA_DIR_NAME.."/allowlist.txt"

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
    if not io.exists(ALLOWLIST_PATH) then
        PEARL.info("Allowlist file not found. Creating a new one...")
        return self:Save()
    end

    -- We do not care about the order so create an key-value table
    -- for faster and easier access.
    for line in io.lines(ALLOWLIST_PATH) do
        -- Strip the lines because of the annoying '\r' on Windows...
        self:Add(line:strip())
    end
end

function AllowList:Save()
    local file, msg = io.open(ALLOWLIST_PATH, "w")
    if file == nil then
        PEARL.error("Couldn't create the allowlist file:\n", msg)
        return false
    end

    for userid, allowed in pairs(self._userids) do
        if allowed == true then
            local _, errmsg = file:write(userid, "\n")
            if errmsg then
                PEARL.error("Couldn't write to the allowlist:\n", errmsg)
                return false
            end
        end
    end

    return file:close()
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
-- [[ Setup ]]
--------------------------------------

-- Master does handle all the connections.
if TheShard:IsMaster() then
    PEARL.AddGlobalFunctionPreCall("JoinServerFilter", function(userid)
        -- IsEnabled return value can be changed during runtime!
        -- TheNet:GetUserID returns the owner's ID on dedicated servers.
        if AllowList:IsEnabled() and not (
            PEARL.AdminList:Contains(userid) or
            userid == TheNet:GetUserID()
        ) and not AllowList:Contains(userid) then
            PEARL.info("Client", userid, "not whitelisted.")

            if TheWorld then
                TheWorld:PushModEvent("clientconnectionclosed", {
                    userid = userid, reason = "ID_DST_SLOT_RESERVATION"
                })
            end

            return false
        end

        -- Else let the the default callback execute.
        -- It should return always true.
    end)
end

-- PEARL.EventProcessor:AddEventHandler("quit", function()
--     AllowList:Save()
-- end)

return AllowList
