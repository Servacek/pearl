--[[
    Checks the content of an inventory when it's owner despawns.
    Logs suspicious intentories to discord.
--]]

local PEARL = PEARL

-------------------------------
-- [[ Event Handlers ]]
-------------------------------

--- @TODO
local function CheckPlayersInventory(world, player)
    if player.admin or player.components.age and player.components.age:IsTrustworthy() then
        return
    end

    if player.components.inventory:CalcSuspicioness() > .9 then
        PEARL.info("Suspicious inventory detected! Owner:", player.name or player.userid)
        local inventory, prefab, name = PEARL.GetInventoryTabelFor(player.userid, player)
        local embed = PEARL.InventoryToEmbed(inventory, prefab, player.name or name, player.userid)
        PEARL.DiscordLogger:LogEmbed(embed)
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
