
local Embed = PEARL.loadfile("libraries/discordapi/models/embed")
local UserCommands = require("usercommands")
local EncodeBase64 = require('utils/base64encoder')

--------------------------------

local TheSim, TheShard, TheNet, bit = TheSim, TheShard, TheNet, bit
local ParseUserSessionData = ParseUserSessionData
local string, table, math = string, table, math

--------------------------------

local KLEI_DATA_PATTERN = "KLEI     1D%s"

--------------------------------
-- [[ Inventory ]]
--------------------------------

function PEARL.GetStackSize(item)
    if item.components and item.components.stackable then
        return item.components.stackable:StackSize()
    elseif item.data and item.data.stackable then
        return item.data.stackable.stack
    else
        return 1
    end
end

-- Returns a table with format {prefab=count}, owners prefab, name and age on success
-- otherwise -> nil
function PEARL.GetInventoryTabelFor(ku_id, player)
    if ku_id == nil and player == nil then return end

    local target_prefab, target_name--, target_age
    local inventory = {}

    local function AddToInv(item)
        if not item then return end

        if item.prefab then
            if not inventory[item.prefab] then
                inventory[item.prefab] = 0
            end

            inventory[item.prefab] = inventory[item.prefab] + PEARL.GetStackSize(item)
        end
    end

    local function ProcessInvItem(item)
        if not item then return end

        AddToInv(item)

        -- for bundles and gifts
        if item.components and item.components.unwrappable and item.components.unwrappable.itemdata then
            for _, v in pairs(item.components.unwrappable.itemdata) do
                AddToInv(v)
            end
        end
    end

    -- If the player is currently playing on the server
    player = player or LookupPlayerInstByUserID(ku_id)
    if player and player.components.inventory then
        local inv = player.components.inventory

        target_prefab = player.prefab
        target_name = player:GetDisplayName() or player.name

        -- we also want to check walter's woby
        if player.woby and player.woby.components and player.woby.components.container then
            player.woby.components.container:ForEachItem(ProcessInvItem)
        end

        --- [[ Main inventory ]] ---
        inv:ForEachItem(ProcessInvItem)

        return inventory, target_prefab, target_name--, target_age
    end

    -- The player is not online so we will try to get the saved inventory
    --print("Selected player is currently not playing on the server.")
    --print("Trying to load saved inventory for this player...")
    local sessionid = TheNet:GetSessionIdentifier()
    local file = TheNet:GetUserSessionFile(sessionid, ku_id)
    if file ~= nil then
        TheNet:DeserializeUserSession(file, function(success, str)
            if success and str then
                local playerdata, _ = ParseUserSessionData(str)

                if not playerdata or not playerdata.data or not playerdata.data.inventory then
                    return
                end

                target_prefab = playerdata.prefab
                -- target_age = playerdata.age
                local inv_data = playerdata.data.inventory

                -- we also want to check walter's woby
                if playerdata.data.woby and playerdata.data.woby.data and playerdata.data.woby.data.container
                and playerdata.data.woby.data.container.items then
                    for _, v in pairs(playerdata.data.woby.data.container.items) do
                        AddToInv(v)
                    end
                end

                --- [[ Main Inventory ]] ---
                if inv_data.items then
                    for _, item in pairs(inv_data.items) do
                        AddToInv(item)

                        -- for bundles
                        if item.data and item.data.unwrappable and item.data.unwrappable.items then
                            for _, v in pairs(item.data.unwrappable.items) do
                                AddToInv(v)
                            end
                        end
                    end
                end

                if not inv_data.equip then return end

                --- [[ Equip slots ]] ---
                local body_slot_item = inv_data.equip.body
                local hands_slot_item = inv_data.equip.hands
                local head_slot_item = inv_data.equip.head

                if hands_slot_item then
                    AddToInv(hands_slot_item)
                end

                if body_slot_item then
                    AddToInv(body_slot_item)

                    -- In case of a backpack
                    if body_slot_item.data and body_slot_item.data.container and body_slot_item.data.container.items then
                        for _, item in pairs(body_slot_item.data.container.items) do
                            AddToInv(item)

                            -- for bundles inside the backpack
                            if item.data and item.data.unwrappable and item.data.unwrappable.items then
                                for _, v in pairs(item.data.unwrappable.items) do
                                    AddToInv(v)
                                end
                            end
                        end
                    end
                end

                if head_slot_item then
                    AddToInv(head_slot_item)
                end
            end
        end)

        return inventory, target_prefab, target_name
    end
end

--- @TODO move this elsewhere + add some more info about the inv (age, item count, etc...)
function PEARL.InventoryToEmbed(inventory, target_prefab, name, userid)
    if not (inventory and (userid or name)) then
        return
    end

    name = name or userid or string.capitalize(target_prefab) or STRINGS.PEARL.UNKNOWN
    local icon = PEARL.ICONS.PLAYER_PREFABS[target_prefab] or PEARL.ICONS.PLAYER_PREFABS[""]
    local title = STRINGS.PEARL.LOGS.INV_REPORT_TITLE:format(icon, name)

    local description = ""
    for prefab, count in pairs(inventory) do
        local name = PEARL.PrefabToName(prefab)
        local is_rare = PEARL.PREFABS.RARE_ITEMS[prefab]

        -- If the item is rare we want to make it bold
        if is_rare then
            description = description..STRINGS.PEARL.LOGS.INV_REPORT_ITEM_RARE:format(
                count, name, prefab
            )
        else
            description = description..STRINGS.PEARL.LOGS.INV_REPORT_ITEM:format(
                count, name, prefab
            )
        end

        description = description.."\n"
    end

    if #description <= 0 then
        description = STRINGS.PEARL.LOGS.INV_REPORT_EMPTY
    end

    return Embed()
        :SetTitle(title)
        :SetDescription(description)
end

--------------------------------
-- [[ Server Commands ]]
--------------------------------

-- TODO: add support for all param
--- @param all any Whether campfires and staff lights should be removed too or not
function PEARL.ExtinguishFiresNear(x, y, z, all)
    if x ~= nil and y ~= nil and z ~= nil then
        -- local mustoneoftags = {'fire','smolder'}
        -- if all then
        --     table.insert(mustoneoftags, "heater")
        -- end

        local fire_entities = TheSim:FindEntities(
            x, y, z, PEARL.CONSTS.EXTINGUISH_RADIUS,
            nil, -- must-have tags
            {'wildfireprotected', 'campfire', 'NOCLICK', 'FX','DECOR','INLIMBO','burnt'}, -- cant-have tags
            {'fire','smolder'} -- must-have-one tags
        )

        for _, ent in pairs(fire_entities) do
            if ent.components and ent.components.burnable then
                ent.components.burnable:Extinguish()
            end

            -- if all and ent:IsValid() and SUB.PREFABS.FIRE_SOURCES[ent.prefab] then
            --     ent:Remove()
            -- end
        end
    end
end

function PEARL.RollbackByDays(cycles)
    -- Note: This returns an array where the snapshots are sorted by the newest
    -- So the snapshot on index 1 is the latest, etc...
    local snapshots = TheNet:ListSnapshots(TheNet:GetSessionIdentifier(), true)
    if type(snapshots) ~= "table" then
        return PEARL.error("Failed to load the list of snapshots!")
    end

    local target_cycle = math.max((TheWorld.state.cycles or 1) - cycles, 1)
    local function onsnapshotloaded(str, id)
        id = id or 1

        if str then
            local noerror, metadata = RunInSandbox(str)
            if noerror and metadata.clock and metadata.clock.cycles then
                if metadata.clock.cycles < target_cycle then
                    return PEARL.info("No snapshot found for day", target_cycle)
                end

                if metadata.clock.cycles == target_cycle then
                    PEARL.info("Rolling server back to cycle", target_cycle)
                    -- Using raw low-level 'TheNet:TruncateSnapshots' instead of
                    -- the default 'WorldRollbackFromSim' because of the 30 seconds limit.
                    TheNet:TruncateSnapshots(
                        TheNet:GetSessionIdentifier(), -id
                    )

                    -- Restart the server after truncating the snapshots
                    -- to apply the changes
                    return WorldRollbackFromSim(0)
                end
            end
        end

        local nextid = id + 1
        local nextsnapshot = snapshots[nextid]
        if not nextsnapshot then
            return PEARL.info("No snapshot found for day", target_cycle)
        end

        return TheSim:GetPersistentString(nextsnapshot.world_file..".meta", function(success, str)
            if success then
                onsnapshotloaded(str, nextid)
            end
        end)
    end

    onsnapshotloaded()
end

function PEARL.SafeShutdownAllShards()
    -- Send to all connected shards (including us)
    PEARL.SendRPCToShard(PEARL.RPCS.ExecuteBroadcast, nil, "c_shutdown(true)")
end

--------------------------------
-- [[ Getters/Checks ]]
--------------------------------

function PEARL.GetShardName()
    return (TheShard:IsMaster() and "Master")
    or (TheShard:IsSecondary() and "Caves")
    or "Unknown"
end

function PEARL.GetSeasonFancyName()
    if not (TheWorld and TheWorld.state) then
        return STRINGS.PEARL.SEASON_UNKNOWN
    end

    local season_prefab = TheWorld.state.season
    local remainingdaysinseason = TheWorld.state.remainingdaysinseason
    local elapseddaysinseason = TheWorld.state.elapseddaysinseason

    if not (season_prefab and remainingdaysinseason and elapseddaysinseason) then
        return STRINGS.PEARL.SEASON_UNKNOWN
    end

    local season_prefix
    local season_name = STRINGS.UI.SERVERLISTINGSCREEN.SEASONS[string.upper(season_prefab)]
    if remainingdaysinseason * 3 <= elapseddaysinseason then
        season_prefix = STRINGS.PEARL.SEASON_PREFIX_LATE[season_prefab]
    elseif elapseddaysinseason * 3 <= remainingdaysinseason then
        season_prefix = STRINGS.PEARL.SEASON_PREFIX_EARLY[season_prefab]
    end

    return (season_prefix or "").." "..season_name
end

function PEARL.CheckForReedTrap()
    for _, v in pairs(Ents) do
        if v.prefab == "reeds" then
            local x, y, z = v.Transform:GetWorldPosition()
            local reed_trap_ents = TheSim:FindEntities(
                x, y, z, 6, nil, nil, {"silviculture", "tentacle"}
            )

            if #reed_trap_ents > 8 then
                return true
            end
        end
    end

    return false
end

function PEARL.IsFirstLaunch()
    -- initial + current
    return TheSim:GetNumLaunches() == 2
end

function PEARL.IsEmoteCommand(cmd_name)
    local command = UserCommands.GetCommandFromName(cmd_name)

    return command and command.emote == true
end

function PEARL.IsCommandAllowed(cmd_name)
    return cmd_name and not table.contains(PEARL.CONFIG.COMMAND_BLOCKLIST, cmd_name)
end

-- function PEARL.IsBase(entities)
--     if not (entities and type(entities) == "table") then
--         return false
--     end

--     local base_structs_count = #(table.filter(entities, function(k, v)
--         return v and v:IsBaseStructure()
--     end))

--     return base_structs_count > 3, base_structs_count
-- end

-- Used to determine wheter the client is connecting to the server for the first time
-- or just migrating between the server shards.
function PEARL.IsClientMigrating(client)
    return client.prefab ~= "" and client.lobbycharacter == "" and client.playerage > 0
end

function PEARL.IsAdminUserid(userid)
    local client = TheNet:GetClientTableForUser(userid)
    return client and client.admin
end

--- @TODO
-- function PEARL.IsBurnable(inst)
--     return inst ~= nil and inst.components ~= nil and inst.components.burnable ~= nil
-- end

--------------------------------
-- [[ Klei Data ]]
--------------------------------

function PEARL.EncodeKleiData(data)
    return KLEI_DATA_PATTERN:format(EncodeBase64(data))
end

function PEARL.DecodeKleiData(data)
    return TheSim:DecodeKleiData(data) or data
end

--------------------------------
-- [[ Utils ]]
--------------------------------

function PEARL.PrefabToName(prefab)
    return STRINGS.NAMES[string.upper(prefab)] or prefab or "MISSING_NAME"
end

function PEARL.FancyTableConcat(t)
    return #t > 1 and STRINGS.PEARL.LOGS.AND:format(
        table.concat(t, ", ", 1, #t-1), t[#t]
    ) or table.concat(t, ", ")
end

function PEARL.BuildFancyStringForEntities(entities)
    local fancy_names = {}
    for _, entity in ipairs(entities) do
        fancy_names[#fancy_names+1] = entity:GetFancyName()
    end

    return PEARL.FancyTableConcat(fancy_names)
end

function PEARL.FormatSortedPrefabs(prefabs)
    local result = ""
    local sep = ""
    local first = true
    for name, count in pairs(prefabs) do
        -- if we are on the last prefab
        if not first and next(prefabs, name) == nil then
            result = result.." "..STRINGS.PEARL.LOGS.AND.." "
            sep = ""
        end

        name = STRINGS.NAMES[string.upper(name)] or name
        if count and count > 1 then
            result = result..count.."x "..name..sep
        else
            result = result..name..sep
        end

        if first then
            first = false
            sep = ", "
        end
    end

    return result
end

function PEARL.SortPrefabs(list, center)
    local prefabs = {}
    local length = 0
    for _, ent in pairs(list) do
        if ent ~= center then -- shouldn't be needed
            -- Try to use the basic names here since it's not possible
            -- to find name for all avaible prefabs in STRINGS.NAMES.
            -- Example is flower_cave_double - Light Flower
            if not prefabs[ent:GetBasicDisplayName()] then
                prefabs[ent:GetBasicDisplayName()] = 1
                length = length + 1
            else
                prefabs[ent:GetBasicDisplayName()] = prefabs[ent:GetBasicDisplayName()] + 1
            end
        end
    end

    return PEARL.FormatSortedPrefabs(prefabs)
end

-- Runs a function and catches errors during the call.
-- Return values are the same as for calling it via pcall function.
function PEARL.SafeRun(func, ...)
    if not func then
        PEARL.info("SafeRun", "[Warning] Tryed to run a non existing function!")
        return false
    end

    local success, result = pcall(func, ...)
    if not success and result then
        PEARL.error(
            "Catched an error while safe executing function", debug.getinfo(func, "n").name, "\n"..tostring(result)
        )

        PEARL.DiscordReporter:ReportModError(result)
    end

    return success, result
end

function PEARL.PercentToRGB(percent)
    return math.floor(percent[1] * 255), math.floor(percent[2] * 255), math.floor(percent[3] * 255)
end

function PEARL.RGBToDecimal(r, g, b)
    return bit.lshift(r, 16) + bit.lshift(g, 8) + b
end

function PEARL.ToISO8601(timestamp)
    return os.date("%Y-%m-%dT%XZ", timestamp)
end

function PEARL.ExtinguishFiresNearAll()
    for _, v in ipairs(AllPlayers) do
        if v.Transform then
            PEARL.ExtinguishFiresNear(v.Transform:GetWorldPosition())
        end
    end

    PEARL.info("Fires near all", AllPlayers and #AllPlayers or 0, "players were extinguished!")
end

function PEARL.RepairStructuresNear(player)
    local x,y,z = player.Transform:GetWorldPosition()
    local burned_entities = TheSim:FindEntities(
        x, y, z, PEARL.CONSTS.REPAIR_RADIUS, {'burnt','structure'}, {'INLIMBO'}
    )

    for _, ent in ipairs(burned_entities) do
        local orig_pos = ent:GetPosition()
        ent:Remove()

        local inst = SpawnPrefab(tostring(ent.prefab), tostring(ent.skinname), nil, player.userid)
        if inst then
            inst.Transform:SetPosition(orig_pos:Get())
        end
    end
end

function PEARL.RepairStructuresNearAll()
    for _, player in ipairs(AllPlayers) do
        PEARL.RepairStructuresNear(player)
    end

    PEARL.info("Burnt structures near all", AllPlayers and #AllPlayers or 0, "players were restored!")
end

function PEARL.UnbanUserByID(userid)
    if PEARL.BlackList:RemovePlayerByID(userid) then
        return PEARL.info("Successfully removed", userid, "from the blocklist!")
    end

    return PEARL.info("Attempt to unban", userid, "failed.")
end

function PEARL.LogInventoryFor(userid)
    if type(userid) ~= "string" then
        return PEARL.error("Invalid userid parameter")
    end

    local inventory, prefab, name = PEARL.GetInventoryTabelFor(userid)
    PEARL.info(DataDumper(inventory))

    local embed = PEARL.InventoryToEmbed(inventory, prefab, name, userid)
    return PEARL.DiscordLogger:LogEmbed(embed)
end
