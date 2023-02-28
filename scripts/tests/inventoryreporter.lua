--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local EMBEDS = PEARL.loadfile("utils/embeds")
local Message = PEARL.loadfile("libraries/discordapi/models/message")

local function GiveItemTo(inst, prefab, count)
    if not inst then
        return
    end

    count = count or 1
    for i = 1, count do
        local item = DebugSpawn(prefab)
        if item ~= nil then
            if item.components.finiteuses then
                item.components.finiteuses:SetUses(math.random(item.components.finiteuses.total))
            end

            --PEARL.debug("giving x"..tostring(count), item)
            inst.components.inventory:GiveItem(item)
        end
    end
end

local function GetSuspicioness(inventory)
    --PEARL.info(string.rep("-", 30))

    -- spawn our thief first
    local thief = c_spawn("wilson")

    for _, item in ipairs(inventory) do
        for prefab, count in pairs(item) do
            GiveItemTo(thief, prefab, count)
        end
    end


    local result = thief.components.inventory:CalcSuspicioness()
    -- if thief.components.inventory:IsSuspicious() then
    --     PEARL.info(string.rep("-", 30))
    --     PEARL.debug("["..tostring(index)..".]", DataDumper(inventory, nil, false, 0))
    --     --PEARL.debug(thief.components.inventory:GetDebugString())
    -- end

    return result, thief
end

function SusInv()
    local rfile, success = io.open(PEARL.ROOTDIR..""..PEARL.DATA_DIR_NAME.."/d_inventories.txt", "r")
    if not rfile then
        return PEARL.error("Failed to open the inventories file!", success)
    end

    local wfile, success = io.open(PEARL.ROOTDIR..""..PEARL.DATA_DIR_NAME.."/d_result.txt", "w")
    if not wfile then
        return PEARL.error("Failed to open the result file!", success)
    end

    PEARL.info("Searching for suspicious inventories...")
    local i = 1
    local count = 0
    for inv_str in rfile:lines() do
        if not inv_str:startswith("--") then
            local inventory = json.decode(inv_str)
            local suspicioness, thief = GetSuspicioness(inventory)
            if suspicioness >= 1 then
                wfile:write("\nINVENTORY: ", i, " ITEM_COUNT: ", #inventory)
                wfile:write("\nSUSPICIONESS: ", math.round((suspicioness * 100), 2), "%")
                wfile:write("\nCONTENT: ", DataDumper(inventory, nil, false, 0))
                wfile:write("\n\n", string.rep("-", 50))

                local player_meta = PEARL.GetPlayerMetadataFor("KU_ZC24p91Q")
                player_meta:SetInventory(thief.components.inventory)
                thief:Remove()
                local message = Message()
                message:AddEmbed(EMBEDS.SuspiciousInventory(player_meta, suspicioness))

                PEARL.info("Sending inventory to discord...")
                return PEARL.DiscordReporter:SendRawReportMessage(message)

                --count = count + 1
            end

            i = i + 1
        end
    end

    wfile:write("\nSUSPICIOUS INVENTORIES DETECTED: ", count)
    wfile:write("\n\n", string.rep("-", 50))

    rfile:close()
    wfile:close()

    PEARL.info("Done! Found:", count)
end
