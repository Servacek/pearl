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

local Message = require("libraries/discordapi/models/message")

-------------------------------
-- [[ Event Handlers ]]
-------------------------------

local function CheckPlayersInventory(world, player)
    if not PEARL.CONFIG.DEBUG_MODE and (player.admin or player.components.age and player.components.age:IsTrustworthy()) then
        return
    end

    local suspicioness = player.components.inventory:CalcSuspicioness()
    if suspicioness > .9 then
        PEARL.info("Suspicious inventory detected! Owner:", player.name or player.userid)

        local age = player.components.age and player.components.age:GetAgeInDays() or STRINGS.PEARL.LOGS.UNKNOWN

        local inventory, prefab, name = PEARL.GetInventoryTabelFor(player.userid, player)
        local embed = PEARL.InventoryToEmbed(inventory, prefab, player.name or name, player.userid)
        embed:SetTitle("")

        local message = Message(STRINGS.PEARL.LOGS.SUSPICIOUS_INVENTORY:format(
            PEARL.ICONS.PLAYER_PREFABS[player.prefab], player:GetDisplayName(), player.userid, age, suspicioness * 100
        ))
        message:AddEmbed(embed)

        PEARL.info("Sending inventory to discord...")
        PEARL.DiscordReporter:SendRawReportMessage(message)
    end
end

-------------------------------
-- [[ Listeners ]]
-------------------------------

PEARL.AddWorldPostInit(function(inst)
    if not (inst and PEARL.CONFIG.DISCORD.LHOOK.ENABLED) then
        return
    end

    inst:SafeListenForEvent("ms_playerdespawn", CheckPlayersInventory)
end)
