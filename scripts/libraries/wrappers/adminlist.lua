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
    Wrapper for engine-provided admin status.

    The engine exposes the admin flag on connected client records, but does not
    expose an admin-list enumeration API. Consequently this wrapper does not
    access adminlist.txt and can only answer for connected users (and the local
    server owner).
]]

local PersistentUserIDList = PEARL.loadlib("wrappers/models/useridlist")

--------------------------------------
-- [[ Constants ]]
--------------------------------------

--------------------------------------
-- [[ Class Declaration ]]
--------------------------------------

--- @singleton
--- @class AdminList: PersistentUserIDList
local AdminList = PersistentUserIDList("engine:adminlist")
AdminList:SetSaveFn(function() end)
AdminList:SetLoadFn(function() end)

-- This is handled by the game itself.
AdminList.Load = function() end
AdminList.Save = function() end

function AdminList:Contains(userid)
    if userid == TheNet:GetUserID() and TheNet:GetIsServerAdmin() then
        return true
    end

    local client = userid and TheNet:GetClientTableForUser(userid)
    return client ~= nil and client.admin == true
end

--------------------------------------
-- [[ Return ]]
--------------------------------------

return AdminList
