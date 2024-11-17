--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local Message = PEARL.loadfile("libs/discordapi/models/message")

local MARKDOWN = PEARL.loadfile("libs/markdown")

--------------------------------
-- [[ Local Variables ]]
--------------------------------

local running, unreachable = false, false

--------------------------------
-- [[ Local Functions ]]
--------------------------------

local function LogProxyStateText(text, has_failed)
    local icon = has_failed and PEARL.ICONS.X or PEARL.ICONS.INFO
    PEARL.DiscordLogger:LogMessage(Message(MARKDOWN.header(
        icon.." "..text, MARKDOWN.HEADER_LEVELS.TINY
    )))


    if has_failed then
        PEARL.DiscordReporter:SendRawReportString(text)
    end
end

--------------------------------
-- [[ Event Handlers ]]
--------------------------------

local function OnProxyServerStart()
    if not running then
        running = true
        LogProxyStateText(STRINGS.PEARL.LOGS.PROXY_SERVER_STARTED)
    end
end

local function OnProxyServerStop()
    if running then
        running = false
        LogProxyStateText(STRINGS.PEARL.LOGS.PROXY_SERVER_STOPPED)
    end
end

local function OnProxyServerRestarted()
    LogProxyStateText(STRINGS.PEARL.LOGS.PROXY_SERVER_RESTARTED)
end

local function OnProxyServerError()
    LogProxyStateText(STRINGS.PEARL.LOGS.PROXY_SERVER_ERROR, true)
end

local function OnProxyServerUnreachable()
    if not unreachable then
        unreachable = true

        LogProxyStateText(STRINGS.PEARL.LOGS.PROXY_SERVER_UNREACH, true)
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
