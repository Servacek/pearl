--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--- @TODO: Sort this a bit (v2.1)


local Embed = PEARL.loadfile("libraries/discordapi/models/embed")
local Message = PEARL.loadfile("libraries/discordapi/models/message")
local UserCommands = require("usercommands")
local EncodeBase64 = PEARL.loadfile('utils/base64encoder')
local MARKDOWN = PEARL.loadfile("libraries/markdown")
local EMBEDS = PEARL.loadfile("utils/embeds")

local PlayerReference = PEARL.loadfile("models/playermetadata")

--------------------------------

local TheSim, TheShard, TheNet, bit = TheSim, TheShard, TheNet, bit
local ParseUserSessionData = ParseUserSessionData
local string, table, math = string, table, math

--------------------------------

local KLEI_ENCODED_DATA_PATTERN = PEARL.CONSTS.KLEI_ENCODED_DATA_PREFIX.."%s"

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

function PEARL.GetPlayerMetadataFor(userid, cb)
    local player_ref = PlayerReference(userid)

    local client = PEARL.ServerNetwork:GetCachedClientTableFor(userid) or TheNet:GetClientTableForUser(userid)
    if client then
        player_ref:SetName(client.name)
        player_ref:SetAge(client.playerage)
        player_ref:SetPrefab(client.prefab)

        -- If the player is playing in the server.
        local player = LookupPlayerInstByUserID(userid)
        if player and player.components and player.components.inventory then
            player_ref:SetInventory(player.components.inventory)
        end

        return player_ref
    end

    local sessionid = TheNet:GetSessionIdentifier()
    local file = TheNet:GetUserSessionFile(sessionid, userid)
    if not file then
        return player_ref
    end

    -- This is some fake async function or something?
    TheNet:DeserializeUserSession(file, function(success, str)
        if not (success and str) then
            return
        end

        local data, _ = ParseUserSessionData(str)
        if not data then
            return
        end

        player_ref:Load(data)
    end)

    return player_ref
end

function PEARL.GetMaxStringSize(string_list, key)
    local max_size = 0
    local size
    for k, v in pairs(string_list) do
        size = key and #tostring(k) or #tostring(v)
        if size > max_size then
            max_size = size
        end
    end

    return max_size
end

--------------------------------
-- [[ Server Commands ]]
--------------------------------

-- TODO: add support for 'all' param
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

--- @param days number The number of cycles to go back. (cycle = day - 1)
--- @param handler function<boolean, string>? The handler function for error messages.
--- @param delay number?
function PEARL.RollbackByDays(days, handler, delay)
    handler = handler or function(...) end

    -- Note: This returns an array where the snapshots are sorted by the newest
    -- So the snapshot on index 1 is the latest, etc...
    local snapshots = TheNet:ListSnapshots(TheNet:GetSessionIdentifier(), true)
    if type(snapshots) ~= "table" then
        handler(false, STRINGS.PEARL.UI.CMD_ERRORS.FAILED_SNAPHOTS_LOAD)
        return PEARL.error("Failed to load the list of snapshots!")
    end

    local target_cycle = math.max((TheWorld.state.cycles or 1) - days, 1)
    local target_day = target_cycle + 1 -- day = cycle + 1 (we are starting from 0)
    local function onsnapshotloaded(str, id)
        id = id or 1

        if str then
            local noerror, metadata = RunInSandbox(str)
            if noerror and metadata.clock and metadata.clock.cycles then
                if metadata.clock.cycles < target_cycle then
                    handler(false, STRINGS.PEARL.UI.CMD_ERRORS.NO_SNAPSHOT_FOUND:format(target_day))
                    return PEARL.info("No snapshot found for day", target_cycle)
                end

                if metadata.clock.cycles == target_cycle then
                    PEARL.Scheduler:ExecuteInTime(delay or 0, function()
                        handler(true, STRINGS.PEARL.LOGS.ROLLBACK_DAYS:format(target_day))
                        PEARL.info("Rolling server back to cycle", target_cycle)

                        -- Using raw low-level 'TheNet:TruncateSnapshots' instead of
                        -- the default 'WorldRollbackFromSim' because of the 30 seconds limit.
                        TheNet:TruncateSnapshots(
                            TheNet:GetSessionIdentifier(), -id
                        )

                        -- Restart the server after truncating the snapshots
                        -- to apply the changes
                        return WorldRollbackFromSim(0)
                    end)
                end
            end
        end

        local nextid = id + 1
        local nextsnapshot = snapshots[nextid]
        if not nextsnapshot then
            handler(false, STRINGS.PEARL.UI.CMD_ERRORS.NO_SNAPSHOT_FOUND:format(target_day))
            return PEARL.info("No snapshot found for day", target_day)
        end

        return TheSim:GetPersistentString(nextsnapshot.world_file..".meta", function(success, str)
            if success then
                onsnapshotloaded(str, nextid)
            end
        end)
    end

    onsnapshotloaded()
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
    local client = userid and TheNet:GetClientTableForUser(userid)
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
    return KLEI_ENCODED_DATA_PATTERN:format(EncodeBase64(data))
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

function PEARL.NameToPrefab(name)
    name = string.lower(name)
    for prefab, pname in pairs(STRINGS.NAMES) do
        if string.lower(pname) == name then
            return prefab
        end
    end

    return name
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


local function format_grouped(grouped)
    local fancy_names = {}
    for name, count in pairs(grouped) do
        if count > 1 then
            fancy_names[#fancy_names + 1] = STRINGS.PEARL.LOGS.ITEM:format(count, name)
        else
            fancy_names[#fancy_names + 1] = name
        end
    end

    return table.fconcat(fancy_names)
end

function PEARL.GroupEntitiesByPrefab(entities)
    local grouped = {}
    for _, ent in ipairs(entities) do
        -- Try to use the basic names here since it's not possible
        -- to find name for all avaible prefabs in STRINGS.NAMES.
        -- Example is flower_cave_double - Light Flower
        local name = ent:GetBasicDisplayName()
        grouped[name] = (grouped[name] or 0) + PEARL.GetStackSize(ent)
    end

    return format_grouped(grouped)
end

function PEARL.GetFuncSrcStr(func)
    local src_info = debug.getinfo(func, "S")
    local filename = PEARL.GetFileNameFromPath(src_info.source) or "unknown"

    return string.format("[%s]:%d:<%d>",
        filename, src_info.linedefined or -1, src_info.currentline or -1
    )
end

-- Runs a function and catches errors during the call.
-- Return values are the same as for calling it via pcall function.
function PEARL.SafeRun(func, ...)
    if type(func) ~= "function" then
        PEARL.warn("Tryed to run a non existing function!")
        return false
    end

    -- #1 is status code
    -- #2 is error message in case the status is false
    local result = {pcall(func, ...)}
    if not result[1] then
        PEARL.error(
            "Error in function call:", result[2] or "Unknown"
        )

        -- This function is being used in frontend as well!
        if PEARL.DiscordReporter then
            PEARL.DiscordReporter:ReportCatchedLuaError(result[2])
        end
    end

    return unpack(result)
end

function PEARL.PercentToRGB(percent)
    return math.floor(percent[1] * 255), math.floor(percent[2] * 255), math.floor(percent[3] * 255)
end

function PEARL.RGBToDecimal(r, g, b)
    return bit.lshift(r, 16) + bit.lshift(g, 8) + b
end

function PEARL.ToISO8601UTC(timestamp)
    -- This is used when sending timestamps to external services (like discord)
    -- which require this format. Such services want the time in UTC so they can
    -- display it for each client according to their timezone.
    --
    -- "!" for UTC time
    return os.date("!%Y-%m-%dT%X", timestamp)
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

        --- @TODO: Does not inherit the builder
        --- Also investigate the 'creator' parameter for TheSim:CreateEntity
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
        PEARL.info("Successfully removed", userid, "from the blocklist!")

        return true
    end

    PEARL.info("Attempt to unban", userid, "failed.")
    return false
end

function PEARL.LogInventoryFor(userid)
    if type(userid) ~= "string" then
        PEARL.error("Invalid userid parameter")

        return false
    end

    local player_meta = PEARL.GetPlayerMetadataFor(userid)
    local message = Message()
    -- Maybe even calculate the suspiciousness here?
    message:AddEmbed(EMBEDS.SuspiciousInventory(player_meta))

    PEARL.DiscordReporter:SendRawReportMessage(message)

    return true
end
