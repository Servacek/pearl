--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--------------------------------
-- [[ Local Variables ]]
--------------------------------

local running, unreachable = false, false

--------------------------------
-- [[ Event Handlers ]]
--------------------------------

local function OnProxyServerStart()
    if not running then
        running = true
        PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_STARTED)
    end
end

local function OnProxyServerStop()
    if running then
        running = false
        PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_STOPPED)
    end
end

local function OnProxyServerRestarted()
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_RESTARTED)
end

local function OnProxyServerError()
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_ERROR)
    PEARL.DiscordReporter:SendRawReportString(STRINGS.PEARL.LOGS.PROXY_SERVER_ERROR)
end

local function OnProxyServerUnreachable()
    if not unreachable then
        unreachable = true

        PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_UNREACH)
        PEARL.DiscordReporter:SendRawReportString(STRINGS.PEARL.LOGS.PROXY_SERVER_UNREACH)
    end
end

--------------------------------
-- [[ Event Listeners ]]
--------------------------------

PEARL.EventProcessor:AddSafeEventHandler("proxy_server_start", OnProxyServerStart)
PEARL.EventProcessor:AddSafeEventHandler("proxy_server_error", OnProxyServerError)
PEARL.EventProcessor:AddSafeEventHandler("proxy_server_stop", OnProxyServerStop)
PEARL.EventProcessor:AddSafeEventHandler("proxy_server_restart", OnProxyServerRestarted)
PEARL.EventProcessor:AddSafeEventHandler("proxy_server_unreachable", OnProxyServerUnreachable)
