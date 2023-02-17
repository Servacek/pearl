--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- Note: Errors before gamelogic won't be loaded.
--- @TODO: In case of mod errors get the afflicter mod.


--[[
    Handles uncatched errors and reports them to discord.
]]

local function OnClientError(traceback)
    -- ClientNetwork should always be
    if PEARL.ClientNetwork then
        PEARL.ClientNetwork:SendErrorTracebackToServer(traceback)
        PEARL.info("We have crashed! Disconnecting the user from the server...")
        PEARL.ClientNetwork:Disconnect("ID_DST_USER_CRASHED")
    else
        PEARL.error("ClientNetwork not initialized yet!")
    end
end

local function OnServerError(traceback)
    if PEARL.DiscordReporter and PEARL.DiscordReporter:IsEnabled() then
        PEARL.DiscordReporter:ReportUncatchedLuaError(traceback)
    else
        PEARL.error("DiscordReporter disabled or not initialized yet!")
    end

    --- @TODO: Maybe some internal "error" event would be better?
    if TheWorld then
        TheWorld:PushModEvent("shard_shutdown", true)
    end

    PEARL.ModShutdown()
    SaveAndShutdown()
end

local function OnError(traceback)
    traceback = traceback or "No Traceback"
    if not TheNet:GetIsClient() then
        return OnServerError(traceback)
    end

    OnClientError(traceback)
end

----------------------------------
-- Post Constuctor
----------------------------------

PEARL.AddGlobalFunctionPreCall("DisplayError", function(traceback)
    -- We do not want more errors
    local success, err = pcall(OnError, traceback)
    if not success then
        PEARL.error("Error while handling an error!\n", err)
    end
end)
