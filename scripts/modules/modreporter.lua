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

--------------------------------------
-- [[ Local Functions ]]
--------------------------------------

local function ReportModsToDiscord(userid, enabled_mods)
    local client = userid and TheNet:GetClientTableForUser(userid)
    local name = client and client.name or userid

    local message = Message()
    message:AddEmbed(EMBEDS.ClientMods(enabled_mods, name))

    PEARL.DiscordReporter:SendRawReportMessage(message)
end

--------------------------------------
-- [[ Setup ]]
--------------------------------------

if PEARL.CONFIG.MOD_BLOCKER.STRICT then
    PEARL.ServerNetwork:AddConnectionFilter(function(userid, data)
        local mods = data and data.enabled_mods and data.enabled_mods.list

        if type(mods) == "table" and tonumber(data.enabled_mods.prohibited_count or 0) > 0 then
            ReportModsToDiscord(userid, data.enabled_mods)

            -- This mod is counted as well!
            if data.enabled_mods.prohibited_count == (data.enabled_mods.count - 1) then
                return false, "ID_DST_ALL_MODS_PROHIBITED"
            end

            return false, "ID_DST_MODS_PROHIBITED"
        end

        return true
    end)
else
    PEARL.EventProcessor:AddSafeEventHandler("clientdatareceived", function(userid, data)
        local mods = data and data.enabled_mods and data.enabled_mods.list

        if type(mods) == "table" and tonumber(data.enabled_mods.prohibited_count or 0) > 0 then
            return ReportModsToDiscord(userid, data.enabled_mods)
        end
    end)
end
