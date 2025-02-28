--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]

---@diagnostic disable: invisible


function TestSendRawReportString()
    PEARL.DiscordReporter:SetIsDisabled(false)
    local result = PEARL.DiscordReporter:SendRawReportString("Test report")
    assert(type(result) == "table")

    PEARL.DiscordReporter:SetIsDisabled(true)
    local resultDisabled = PEARL.DiscordReporter:SendRawReportString("Test report")
    assert(resultDisabled == nil)
    PEARL.DiscordReporter:SetIsDisabled(false)
end

function TestReportCatchedLuaError()
    PEARL.DiscordReporter:SetIsDisabled(false)

    local old_reports = PEARL.DiscordReporter._last_reports
    local traceback = "Catched Error"
    PEARL.DiscordReporter:ReportCatchedLuaError(traceback)
    assert(PEARL.DiscordReporter:_WasErrorReported(traceback))
    assert(old_reports ~= PEARL.DiscordReporter._last_reports )
end

-- function TestDisplayError()
--     DisplayError("Uncatched Test Error")
--     assert(PEARL.DiscordReporter:IsDisabled())
-- end

-- Test the cooldown functionality
function TestCooldown()
    -- Disable the reporter
    PEARL.DiscordReporter:SetIsDisabled(true)

    -- Simulate an error report and check if it's allowed (expect false)
    local errorReported = PEARL.DiscordReporter:HandleError("Disabled")
    assert(errorReported == false)

    -- Enable the reporter
    PEARL.DiscordReporter:SetIsDisabled(false)

    -- Simulate an error report and check if it's allowed (expect true)
    errorReported = PEARL.DiscordReporter:HandleError("Sample Error Traceback")
    assert(errorReported == true)

    -- Try duplicating errors
    errorReported = PEARL.DiscordReporter:HandleError("Sample Error Traceback")
    assert(errorReported == false)

    for i = 1, (PEARL.DiscordReporter._max_reports - PEARL.DiscordReporter._last_reports) do
        assert(PEARL.DiscordReporter:HandleError("Error "..tostring(i)) == true)
    end

    -- Report after maximum has been reached.
    assert(PEARL.DiscordReporter:HandleError("Error Prohibited") == false)

    PEARL.WallScheduler:ExecuteInTime(PEARL.DiscordReporter._cooldown_time, function()
        assert(PEARL.DiscordReporter:HandleError("Error After Cooldown Has Passed") == true)
    end)
end
