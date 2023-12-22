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
-- [[ Event Handlers ]]
--------------------------------

local function OnProxyServerStart()
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_STARTED)
end

local function OnProxyServerStop()
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_STOPPED)
end

local function OnProxyServerRestarted()
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_RESTARTED)
end

local function OnProxyServerError()
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_ERROR)
    PEARL.DiscordReporter:SendRawReportString(STRINGS.PEARL.LOGS.PROXY_SERVER_ERROR)
end

local function OnProxyServerUnreachable()
    PEARL.DiscordLogger:LogString(STRINGS.PEARL.LOGS.PROXY_SERVER_UNREACH)
    PEARL.DiscordReporter:SendRawReportString(STRINGS.PEARL.LOGS.PROXY_SERVER_UNREACH)
end

--------------------------------
-- [[ Event Listeners ]]
--------------------------------

PEARL.EventProcessor:AddEventHandler("proxy_server_start", OnProxyServerStart)
PEARL.EventProcessor:AddEventHandler("proxy_server_error", OnProxyServerError)
PEARL.EventProcessor:AddEventHandler("proxy_server_stop", OnProxyServerStop)
PEARL.EventProcessor:AddEventHandler("proxy_server_restart", OnProxyServerRestarted)
PEARL.EventProcessor:AddEventHandler("proxy_server_unreachable", OnProxyServerUnreachable)
