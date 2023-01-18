--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local Message = PEARL.loadfile("libraries/discordapi/models/message")


PEARL.EventProcessor:AddEventHandler("clientdatareceived", function(userid, data)
    if not (userid and data and data.ping) then
        return
    end

    -- The ping is fine, nothing to report here.
    if data.ping < PEARL.CONSTS.BAD_PING_THRESHOLD then
        return
    end

    local locale = data.locale or "??"
    if PEARL.DiscordReporter and PEARL.DiscordReporter:IsEnabled() then
        PEARL.DiscordReporter:SendRawReportMessage(Message(
            PEARL.ICONS.PING.." "..STRINGS.PEARL.LOGS.HIGH_PING:format(
                data.ping, userid, locale
            )
        ))
    end

    PEARL.warn("Bad server latency ("..tostring(data.ping).."ms) reported from client", userid, "from region", locale)
end)

PEARL.ServerNetwork:SetServerRequiresCFD(true)
