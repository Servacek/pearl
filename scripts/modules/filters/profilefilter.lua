--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


-------------------------------------
-- [[ Local Functions ]]
-------------------------------------

local function RunAsyncProfileFilter(data, filtercb)
    -- Check both because if we have only one set then the query most likely just failed.
    if type(data.communityprofile) ~= "boolean" or type(data.profilerep) ~= "number" then
        return false -- There is still some data to be catched up
    end

    if data.communityprofile == false and PEARL.CONFIG.PROFILE_FILTER.ENSURE_PROFILE == true then
        filtercb(false, "ID_DST_NO_COMMUNITY_PROFILE")
        return true
    end

    if data.profilerep < PEARL.CONFIG.PROFILE_FILTER.MIN_REPUTATION then
        filtercb(false, "ID_DST_PROFILE_REP_TOO_LOW")
        return true
    end

    filtercb(true)
    return true
end

--------------------------------
-- [[ Setup - Server ]]
--------------------------------

PEARL.ServerNetwork:AddAsyncConnectionFilter(function(userid, cb)
    local record = PEARL.DB:GetRecordFor(userid)
    if not record then
        return cb(true)
    end

    if RunAsyncProfileFilter(record, cb) then
        return
    end

    local handler
    handler = PEARL.EventProcessor:AddSafeEventHandler("clientprofiledata", function(target_userid, data)
        if target_userid ~= userid then
            return
        end

        PEARL.EventProcessor:RemoveHandler(handler)
        if not RunAsyncProfileFilter(data, cb) then
            cb(true) -- fail safe if data are still missing
        end
    end)
end)
