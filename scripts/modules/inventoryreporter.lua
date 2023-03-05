--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--[[
    Checks the content of an inventory when it's owner despawns.
    Logs suspicious intentories to discord.
--]]

local Message = PEARL.loadfile("libraries/discordapi/models/message")
local EMBEDS = PEARL.loadfile("utils/embeds")

-------------------------------
-- [[ Event Handlers ]]
-------------------------------

local function CheckPlayersInventory(world, player)
    if type(player) ~= "table" then
        return
    end

    if not PEARL.CONFIG.DEBUG_MODE and (PEARL.ServerNetwork:IsAdmin(player.userid) or (player.components.age and player.components.age:IsTrustworthy())) then
        return
    end

    -- There is no point in announcing the inventory if we drop everything anyway.
    if (GetGameModeProperty("drop_everything_on_despawn") or TUNING.DROP_EVERYTHING_ON_DESPAWN) then
        return
    end

    local suspicioness = player.components.inventory:CalcSuspicioness()
    if suspicioness > .9 then
        PEARL.info("Suspicious inventory detected! Owner:", player.name or player.userid)

        local player_meta = PEARL.GetPlayerMetadataFor(player.userid)
        local message = Message()
        message:AddEmbed(EMBEDS.SuspiciousInventory(player_meta, suspicioness))

        PEARL.info("Sending inventory to discord...")
        PEARL.DiscordReporter:SendRawReportMessage(message)
    end
end

-------------------------------
-- [[ Listeners ]]
-------------------------------

PEARL.AddWorldPostInit(function(inst)
    if not (inst and PEARL.DiscordReporter and PEARL.DiscordReporter:IsEnabled()) then
        return
    end

    -- Question is, if this is being called on migration or not.
    inst:SafeListenForEvent("ms_playerdespawn", CheckPlayersInventory)
end)
