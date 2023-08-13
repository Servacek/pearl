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

-- This is really required!
require("stacktrace")

--- Load as little stuff here as possible since this is loaded at the start.
local EncodeBase64 = PEARL.loadfile('utils/base64encoder')
local PlayerReference = PEARL.loadfile("models/playermetadata")

--------------------------------

local TheSim, TheShard, TheNet, bit = TheSim, TheShard, TheNet, bit
local ParseUserSessionData = ParseUserSessionData
local string, table, math = string, table, math

--------------------------------

local KLEI_ENCODED_DATA_PATTERN = PEARL.CONSTS.KLEI_ENCODED_DATA_PREFIX.."%s"

local KLEI_ID_PATTERN = "KU_"..string.rep("[%d%a%p]", 8)
local STEAM_ID_PATTERN = string.rep("[%d", 17)

--------------------------------
-- [[ Inventory ]]
--------------------------------

function PEARL.GetStackSize(stack)
    if stack.components and stack.components.stackable then
        return stack.components.stackable:StackSize()
    elseif stack.data and stack.data.stackable then
        return stack.data.stackable.stack
    else
        return 1
    end
end

--- @return PlayerMetadata
function PEARL.GetPlayerMetadataFor(userid, cb)
    local player_ref = PlayerReference(userid)

    -- Do not prefer the cached client table since it doesn't have to be up-to-date.
    local client = TheNet:GetClientTableForUser(userid) or PEARL.ServerNetwork:GetCachedClientTableFor(userid)
    if client then
        player_ref:SetName(client.name)
        player_ref:SetAge(client.playerage)
        player_ref:SetPrefab(client.prefab)
        player_ref:SetNetID(client.netid)

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

function PEARL.GetMaxStringSize(string_list, key, keyname)
    local max_size = 0
    local size
    for k, v in pairs(string_list) do
        if not keyname or k == keyname or (type(v) == "table" and v[keyname]) ~= nil then
            size = key and string.utf8len(tostring(k)) or (
                type(v) == "table" and type(v[keyname]) == "string" and string.utf8len(v[keyname])
            ) or string.utf8len(tostring(v)) or 0
            if size > max_size then
                max_size = size
            end
        end
    end

    return max_size
end

--------------------------------
-- [[ Persistent String ]]
--------------------------------
-- A bunch of wrappers for nicer handling of persistent strings.

function PEARL.PersistentStringExists(fp)
    local file_exists = false
    TheSim:CheckPersistentStringExists(fp, function(exists)
        file_exists = exists
    end)

    return file_exists
end

function PEARL.CreatePersistentString(fp)
    return PEARL.SetPersistentString(fp, "")
end

function PEARL.EnsurePersistentString(fp)
    if not PEARL.PersistentStringExists(fp) then
        if not PEARL.CreatePersistentString(fp) then
            PEARL.error("Failed to create file", fp)
            return false
        end
    end

    return true
end

function PEARL.GetPersistentString(fp, ensure)
    if ensure and not PEARL.EnsurePersistentString(fp) then
        return false
    end

    local result, success
    TheSim:GetPersistentString(fp, function(successfull, str)
        success = successfull
        result = str
    end)

    return success, result
end

-- This runs synchronously actually.
function PEARL.GetPersistentStringByLines(fp, fn, ensure)
    if PEARL.PersistentStringExists(fp) ~= true then
        if ensure == true then
            PEARL.info("Creating file", fp)

            return PEARL.CreatePersistentString(fp)
        end

        return PEARL.error("File not found!")
    end

    return TheSim:GetPersistentString(fp, function(success, str)
        if not success or type(str) ~= "string" then
            return PEARL.error("Failed to load the file!", fp)
        end

        local prefix = string.strip(PEARL.CONSTS.KLEI_DATA_PREFIX)
        for _, line in ipairs(str:split("\n")) do
            if string.strip(line) ~= prefix then
                fn(line)
            end
        end
    end)
end

function PEARL.GetAllPersistentStringLines(fp, ensure, strip)
    local lines = {}
    PEARL.GetPersistentStringByLines(fp, function(line)
        if strip == true then
            local stripped = string.strip(line)
            if #stripped > 0 then
                lines[#lines + 1] = stripped
            end
        else
            lines[#lines + 1] = line
        end
    end, ensure)

    return lines
end

function PEARL.SetPersistentString(fp, str, encode)
    encode = encode or false

    local s = false
    TheSim:SetPersistentString(fp, str, encode, function(success)
        s = success
    end)

    return s
end

function PEARL.LoadPersistentLuaString(fp, ensure, env)
    if ensure and not PEARL.EnsurePersistentString(fp) then
        return false, PEARL.error("Failed to create the file!")
    end

    local success, lua_str = PEARL.GetPersistentString(fp, ensure)
    if not success or type(lua_str) ~= "string" then
        return false, PEARL.error("Failed to load the given lua file!")
    end

    if type(env) == "table" then
        return RunInEnvironmentSafe(function()
            return loadstring(lua_str)()
        end, env)
    end

    return RunInSandboxSafe(lua_str)
end

--------------------------------
-- [[ Server Commands ]]
--------------------------------

function PEARL.RawRollbackByID(snapshot_id)
    -- Using raw low-level 'TheNet:TruncateSnapshots' instead of
    -- the default 'WorldRollbackFromSim' because of the 30 seconds limit.
    TheNet:TruncateSnapshots(TheNet:GetSessionIdentifier(), -snapshot_id)

    -- Restart the server after truncating the snapshots
    -- to apply the changes
    return WorldRollbackFromSim(0)
end

--- @param days number The number of cycles to go back. (cycle = day - 1)
--- @param handler function<boolean, string>? The handler function for error messages.
--- @param delay number?
function PEARL.RollbackByDays(days, handler, delay)
    if not TheNet:GetIsServer() then
        return PEARL.error("RollbackByDays works only on the server!")
    end

    handler = handler or function(success, message)
        if success == false then
            return PEARL.error(message)
        end

        return PEARL.info(message)
    end

    -- Note: This returns an array where the snapshots are sorted by the newest
    -- So the snapshot on index 1 is the latest, etc...
    local snapshots = TheNet:ListSnapshots(TheNet:GetSessionIdentifier(), true)
    if type(snapshots) ~= "table" then
        return handler(false, STRINGS.PEARL.UI.CMD_ERRORS.FAILED_SNAPHOTS_LOAD)
    end

    local target_cycle = math.max((TheWorld.state.cycles or 1) - days, 1)
    local target_day = target_cycle + 1 -- day = cycle + 1 (we are starting from 0)

    local function getsnapshotcycle(data)
        if type(data) ~= "string" then
            return
        end

        local success, metadata = RunInSandbox(data)
        if not (success and metadata and metadata.clock) then
            return
        end

        return metadata.clock.cycles
    end

    local function tryloadsnapshot(index)
        local snapshot = snapshots[index]
        if type(snapshot) ~= "table" then
            return handler(false, STRINGS.PEARL.UI.CMD_ERRORS.NO_SNAPSHOT_FOUND:format(target_day))
        end

        return TheSim:GetPersistentString(tostring(snapshot.world_file)..".meta", function(success, data)
            local cycle = getsnapshotcycle(data)
            if type(cycle) ~= "number" then
                return
            end

            if cycle == target_cycle and snapshot.snapshot_id ~= nil then
                handler(true, STRINGS.PEARL.LOGS.ROLLBACK_DAYS:format(target_day))
                return PEARL.WallScheduler:ExecuteInTime(
                    delay or 0, PEARL.RawRollbackByID, nil, snapshot.snapshot_id
                )
            end

            -- The snapshots are being saved in order.
            if cycle > target_cycle then
                -- Looks like this snapshot isn't the target one...
                -- Try to load the next snapshot
                return tryloadsnapshot(index + 1)
            end

            return handler(false, STRINGS.PEARL.UI.CMD_ERRORS.NO_SNAPSHOT_FOUND:format(target_day))
        end)
    end

    -- We are starting from snapshot at index 1 which should be the newest.
    tryloadsnapshot(1)
end

--------------------------------
-- [[ Getters/Checks ]]
--------------------------------

function PEARL.GetShardFancyNameByID(id)
    if id == SHARDID.INVALID then
        return STRINGS.PEARL.SHARDS.UNKNOWN
    end

    return id == SHARDID.MASTER and STRINGS.PEARL.SHARDS.MASTER or STRINGS.PEARL.SHARDS.SECONDARY
end

-- Supports name configuration
function PEARL.GetShardFancyName()
    return PEARL.CONFIG.SHARD_NAME or PEARL.GetShardFancyNameByID(TheShard:GetShardId())
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
    local season_name = STRINGS.PEARL.SEASONS[string.upper(season_prefab)]
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

function PEARL.ToggleEncryptString(str, key)
    local key_len = #key
    local encrypted = {}
    for i = 1, #str do
        encrypted[#encrypted + 1] = bit.bxor(str:byte(i), key:byte((i - 1) % key_len + 1))
    end

    return string.char(unpack(encrypted))
end

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

function PEARL.IsKleiIDValid(kleid)
    return kleid:match(KLEI_ID_PATTERN) ~= nil
end

function PEARL.GetKleiIDFromString(str)

end

function PEARL.GetSteamIDFromString(str)

end

function PEARL.TimestampToTable(timestamp)
    return timestamp and os.date("*t", timestamp)
end

function PEARL.GetMonthFancyName(month_number)
    return STRINGS.PEARL.MONTHS[month_number]
end

function PEARL.TimestampToFancyDateString(timestamp)
    local date_tbl = PEARL.TimestampToTable(timestamp)

    return STRINGS.PEARL.DATE_FORMAT:format(
        date_tbl.day,
        PEARL.GetMonthFancyName(date_tbl.month),
        date_tbl.year
    )
end

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

-- function PEARL.IsValidKleiID(kleid)
--     return kleid and type(kleid) == "string" and kleid:match()
-- end

function PEARL.BuildFancyStringFor(grouped)
    local fancy_names = {}
    for name, count in pairs(grouped) do
        fancy_names[#fancy_names+1] = count > 1 and STRINGS.PEARL.LOGS.ITEM:format(
            count, name
        ) or name
    end

    return PEARL.FancyTableConcat(fancy_names)
end

function PEARL.BuildFancyStringForEntities(entities)
    return PEARL.BuildFancyStringFor(PEARL.GroupEntitiesByPrefab(entities))
end

function PEARL.GetStandardizedNameFor(entity)
    if type(entity) ~= "table" then
        return  tostring(entity)
    end

    --- For players
    if entity.userid then
        return entity:GetDisplayName()
    end

    return entity and (STRINGS.NAMES[string.upper(entity.prefab)] or entity:GetBasicDisplayName())
end

--- @deprecated
-- function PEARL.FormatSortedPrefabs(prefabs)
--     local result = ""
--     local sep = ""
--     local first = true
--     for name, count in pairs(prefabs) do
--         -- if we are on the last prefab
--         if not first and next(prefabs, name) == nil then
--             result = result.." "..STRINGS.PEARL.LOGS.AND.." "
--             sep = ""
--         end

--         name = STRINGS.NAMES[string.upper(name)] or name
--         if count and count > 1 then
--             result = result..count.."x "..name..sep
--         else
--             result = result..name..sep
--         end

--         if first then
--             first = false
--             sep = ", "
--         end
--     end

--     return result
-- end

-- function PEARL.SortPrefabs(list, center)
--     local prefabs = {}
--     local length = 0
--     for _, ent in pairs(list) do
--         if ent ~= center then -- shouldn't be needed
--             -- Try to use the basic names here since it's not possible
--             -- to find name for all avaible prefabs in STRINGS.NAMES.
--             -- Example is flower_cave_double - Light Flower
--             if not prefabs[ent:GetBasicDisplayName()] then
--                 prefabs[ent:GetBasicDisplayName()] = 1
--                 length = length + 1
--             else
--                 prefabs[ent:GetBasicDisplayName()] = prefabs[ent:GetBasicDisplayName()] + 1
--             end
--         end
--     end

--     return PEARL.FormatSortedPrefabs(prefabs)
-- end


-- local function format_grouped(grouped)
--     local fancy_names = {}
--     for name, count in pairs(grouped) do
--         if count > 1 then
--             fancy_names[#fancy_names + 1] = STRINGS.PEARL.LOGS.ITEM:format(count, name)
--         else
--             fancy_names[#fancy_names + 1] = name
--         end
--     end

--     return table.fconcat(fancy_names)
-- end

function PEARL.GroupEntitiesByPrefab(entities)
    local grouped = {}
    for _, ent in ipairs(entities) do
        -- Try to use the basic names here since it's not possible
        -- to find name for all avaible prefabs in STRINGS.NAMES.
        -- Example is flower_cave_double - Light Flower
        local name = ent:GetBasicDisplayName()
        grouped[name] = (grouped[name] or 0) + PEARL.GetStackSize(ent)
    end

    return grouped
end

function PEARL.GetBurnableEntitiesNearPos(pos, radius)
    return TheSim:FindEntities(pos.x, pos.y, pos.z, radius,
        PEARL.CONSTS.ENT_MUST_HAVE_TAGS,
        PEARL.CONSTS.ENT_CANT_HAVE_TAGS,
        PEARL.CONSTS.ENT_ONEOF_TAGS
    )
end

function PEARL.GetFuncSrcStr(func)
    local src_info = debug.getinfo(func, "S")
    local filename = PEARL.GetFileNameFromPath(src_info.source) or "unknown"

    return string.format("[%s]:%d:<%d>",
        filename, src_info.linedefined or -1, src_info.currentline or -1
    )
end

-- Runs a function and catches errors during the call.
-- Return values are the same as for calling it via xpcall function.
--
-- Note: This is not the most efficient thing so run it only
-- on places where we do not care about time.
function PEARL.SafeRun(func, ...)
    if type(func) ~= "function" then
        PEARL.warn("Tryed to run a non existing function!")
        return false
    end

    local args = toarrayornil(...)
    -- #1 is status code
    -- #2 is error message in case the status is false
    local result = {xpcall(
        function()
            if args then
                return func(unpack(args))
            end

            return func()
        end,
        function(err)
            local stacktrace = StackTrace(err)
            PEARL.error(
                "Error in function call:", stacktrace or "Unknown"
            )

            if stacktrace then
                -- This function is being used in frontend as well!
                if PEARL.DiscordReporter then
                    PEARL.DiscordReporter:ReportCatchedLuaError(stacktrace)
                elseif PEARL.ClientNetwork then
                    PEARL.ClientNetwork:SendErrorTracebackToServer(stacktrace)
                end
            end
        end
    )}

    return unpack(result)
end

function PEARL.PercentToRGB(percent)
    return math.floor(percent[1] * 255), math.floor(percent[2] * 255), math.floor(percent[3] * 255)
end

-- The input can be either individual numbers or a RGB table.
function PEARL.RGBToDecimal(r, g, b)
    if type(r) == "table" then
        b = r.b or r[3]
        g = r.g or r[2]
        r = r.r or r[1]
    end

    return bit.lshift((r or 0), 16) + bit.lshift((g or 0), 8) + (b or 0)
end

-- Does return r, g, b separately, use GetColorFromDecimal for a color table.
function PEARL.DecimalToRGB(decimal)
    if type(decimal) ~= "number" then
        return
    end

    return bit.band(bit.rshift(decimal, 16), 0xFF), bit.band(bit.rshift(decimal, 8), 0xFF), bit.band(decimal, 0xFF)
end

function PEARL.RGBToHex(r, g, b)
    return string.format("#%06X", PEARL.RGBToDecimal(r, g, b))
end

function PEARL.GetColorFromDecimal(decimal, default)
    return type(decimal) == "number" and {PEARL.DecimalToRGB(decimal)} or (default or WHITE)
end

function PEARL.ToISO8601UTC(timestamp)
    -- This is used when sending timestamps to external services (like discord)
    -- which require this format. Such services want the time in UTC so they can
    -- display it for each client according to their timezone.
    --
    -- "!" for UTC time
    return os.date("!%Y-%m-%dT%X", timestamp)
end

function PEARL.ExtinguishFires(x, y, z, radius)
    local onfire = TheSim:FindEntities(x, y, z, radius,
        nil, -- must-have tags
        {'wildfireprotected', 'campfire', 'NOCLICK', 'FX','DECOR','INLIMBO','burnt'}, -- cant-have tags
        {'fire','smolder'} -- must-have-one tags
    )

    for i = 1, #onfire do
        if onfire[i].components and onfire[i].components.burnable then
            onfire[i].components.burnable:Extinguish()
        end
    end
end

function PEARL.ExtinguishAllFires()
    -- Extinguish fires all around the world.
    PEARL.ExtinguishFires(0, 0, 0, WORLD_TILES_OCEAN_SIZE)

    PEARL.info("All world fires were extinguished!")
end

function PEARL.ExtinguishFiresNearAll()
    if #AllPlayers > 0 then
        return PEARL.info("Server is empty")
    end

    for _, v in ipairs(AllPlayers) do
        if v.Transform then
            PEARL.ExtinguishFires(v.Transform:GetWorldPosition(), PEARL.CONSTS.EXTINGUISH_RADIUS)
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
        --- @TODO: Does not inherit the builder
        --- Also investigate the 'creator' parameter for TheSim:CreateEntity
        ReplacePrefab(ent, ent.prefab, ent.skinname, ent.skin_id, player.userid)
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

        PEARL.EventProcessor:HandleEvent("clientunbanned", userid)

        return true
    end

    PEARL.info("Attempt to unban", userid, "failed.")
    return false
end
