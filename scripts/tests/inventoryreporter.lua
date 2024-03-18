--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


PEARL.SUS_COUNT = 0

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
            if not inst.components.inventory:GiveItem(item) then
                print("Failed to add item", item, inst.components.inventory:IsFull())
            end
        end
    end

    print(inst.components.inventory:GetDebugString())
end

local function CreateThief(inventory)
    -- spawn our thief first
    local thief = c_spawn("wilson")

    rawset(thief.components.inventory, "maxslots", 200)

    for _, item in ipairs(inventory) do
        for prefab, count in pairs(item) do
            GiveItemTo(thief, prefab, tonumber(count))
        end
    end

    return thief
end

function SusInv()
    local rfile, success = io.open(MODROOT..""..PEARL.DATA_DIR_NAME.."/d_inventories.txt", "r")
    if not rfile then
        return PEARL.error("Failed to open the inventories file!", success)
    end

    local wfile, success = io.open(MODROOT..""..PEARL.DATA_DIR_NAME.."/d_result.txt", "w")
    if not wfile then
        return PEARL.error("Failed to open the result file!", success)
    end

    PEARL.info("Searching for suspicious inventories...")
    local i = 1
    local count = 0
    for inv_str in rfile:lines() do
        if not inv_str:startswith("--") then
            if i > 100 then
                break
            end

            local inventory = json.decode(inv_str)
            local thief = CreateThief(inventory)
            assert(type(thief) == "table", "Failed to spawn the thief!")
            print("INVENTORY:", DataDumper(inventory))

            thief.userid = "KU_ZC24p91Q"
            thief.name = "Fi7iP"

            PEARL.EventProcessor:HandleEvent("d_ms_playerdespawn", TheWorld, thief)

            thief:Remove()

            -- if suspicioness >= .9 then

            --     local player_meta = PEARL.GetPlayerMetadataFor("KU_ZC24p91Q")
            --     player_meta:SetInventory(thief.components.inventory)
            --     thief:Remove()
            --     local message = Message()
            --     message:AddEmbed(EMBEDS.SuspiciousInventory(player_meta, suspicioness))

            --     PEARL.info("Sending inventory to discord...")
            --     PEARL.DiscordReporter:SendRawReportMessage(message)

            --     count = count + 1
            -- end

            i = i + 1
        end
    end

    -- wfile:write("\nSUSPICIOUS INVENTORIES DETECTED: ", count)
    -- wfile:write("\n\n", string.rep("-", 50))

    rfile:close()
    wfile:close()

    PEARL.info("Done! Found:", PEARL.SUS_COUNT)
    PEARL.SUS_COUNT = 0
end
