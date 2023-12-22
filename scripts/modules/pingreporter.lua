--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--- @TODO: Remake this to be a client module.
local Message = PEARL.loadfile("libraries/discordapi/models/message")

--------------------------------------
-- [[ Locals ]]
--------------------------------------

local function OnBadClientLatency(userid, latency, locale)
    locale = locale or "??"
    if PEARL.DiscordReporter and PEARL.DiscordReporter:IsEnabled() then
        PEARL.DiscordReporter:SendRawReportMessage(Message(
            PEARL.ICONS.PING.." "..STRINGS.PEARL.LOGS.HIGH_PING:format(
                latency, userid, locale
            )
        ))
    end

    PEARL.warn("Bad latency ("..tostring(latency).."ms) reported from client", userid, "from region", locale)
end

local function OnBadServerPerformance()
    if PEARL.DiscordReporter and PEARL.DiscordReporter:IsEnabled() then
        PEARL.DiscordReporter:SendRawReportMessage(Message(
            PEARL.ICONS.PING.." "..STRINGS.PEARL.LOGS.LOW_PERFORMANCE
        ))
    end

    PEARL.warn("Received bad server performance report from client.")
end

--------------------------------------
-- [[ Client Latency ]]
--------------------------------------

PEARL.EventProcessor:AddSafeEventHandler("clientdatareceived", function(userid, data)
    if not (userid and data and data.ping) or not data.waiting then
        return
    end

    -- We are comparing logical values here.
    if data.performance >= PEARL.CONSTS.BAD_PERFORMANCE_THRESHOLD then
        return OnBadServerPerformance()
    end

    -- The ping is fine, nothing to report here.
    if data.ping > PEARL.CONSTS.BAD_PING_THRESHOLD then
        return OnBadClientLatency(userid, data.ping, data.locale)
    end
end)

PEARL.ServerNetwork:SetServerRequiresCFD(true)
