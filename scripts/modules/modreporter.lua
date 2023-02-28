--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @category Backend



--[[
    Receives the mod report from the client and verifies
    whether the mods the client is using are allowed or not.
    If the mod blocker's strict mode is enabled,
--]]

local Message = PEARL.loadfile("libraries/discordapi/models/message")
local EMBEDS = PEARL.loadfile("utils/embeds")


PEARL.EventProcessor:AddSafeEventHandler("clientdatareceived", function(userid, data)
    if not (data and data.enabled_mods and data.enabled_mods.prohibited == true) then
        return
    end

    local client = userid and TheNet:GetClientTableForUser(userid)
    local name = client and client.name or userid

    local message = Message()
    message:AddEmbed(EMBEDS.ClientMods(data.enabled_mods, name))

    PEARL.DiscordReporter:SendRawReportMessage(message)
end)
