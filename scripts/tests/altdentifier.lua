--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]




local tests = {}

function tests.test_all()
    if not PEARL.CONFIG.BAN_ALT_ACCOUNTS then
        return PEARL.warn("Altdentifier is disabled!")
    end

    PEARL.info("=============== START ===============")
    local init_request_count = PEARL.HTTPClient:GetSentRequestsCount()

    PEARL.info("=============== TEST BANNED VALID ROOT ===============")
    TheWorld:PushEvent("ms_clientauthenticationcomplete", {userid ="KU_ZC24p91Q"})

    PEARL.WallScheduler:ExecuteInTime(10, function()
        PEARL.info("=============== TEST BANNED ROOT ===============")
        TheNet:Ban("KU_NujB7r1v")
        TheWorld:PushEvent("ms_clientauthenticationcomplete", {userid = "KU_0Z4zp1dv"})
    end)

    PEARL.WallScheduler:ExecuteInTime(20, function()
        PEARL.info("=============== TEST INVALID USERID ===============")
        TheWorld:PushEvent("ms_clientauthenticationcomplete", {userid = "KU_TEST"})
    end)

    PEARL.WallScheduler:ExecuteInTime(30, function()
        PEARL.info("=============== TEST CACHED USERID ===============")
        TheWorld:PushEvent("ms_clientauthenticationcomplete", {userid = "KU_ZC24p91Q"})
    end)

    -- Comment out "E_OWNERSHIP_MISSING" in DO_NOT_RETRY_ERRORS table
    -- in order for this to work.
    PEARL.WallScheduler:ExecuteInTime(40, function()
        PEARL.info("=============== TEST RETRY ===============")
        TheWorld:PushEvent("ms_clientauthenticationcomplete", {userid = "KU_ZC24p91X"})
    end)

    PEARL.WallScheduler:ExecuteInTime(60, function()
        PEARL.info("=============== END ===============")
        local current_requests_count = PEARL.HTTPClient:GetSentRequestsCount()
        PEARL.info("Requests Sent:", current_requests_count - init_request_count)
    end)
end

return tests
