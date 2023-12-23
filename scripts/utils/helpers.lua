--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
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

local KLEI_ID_PATTERN   = PEARL.CONSTS.KLEI_ID_PATTERN
local STEAM_ID_PATTERN  = PEARL.CONSTS.STEAM_ID_PATTERN

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

--- @DONOTUSE
--- @param days string The number of cycles to go back. (cycle = day - 1)
---- @param handler function<boolean, string>? The handler function for error messages.
--- @param after integer?
--- @return boolean success, string? reason
function PEARL.RollbackByDays(days, handler, after)
    if not TheNet:GetIsServer() then
        return false, STRINGS.PEARL.UI.CMD_ERRORS.SERVER_ONLY
    end

    -- handler = handler or function(success, message)
    --     if success == false then
    --         return PEARL.error(message)
    --     end

    --     return PEARL.info(message)
    -- end

    -- Note: This returns an array where the snapshots are sorted by the newest
    -- So the snapshot on index 1 is the latest, etc...
    local snapshots = TheNet:ListSnapshots(TheNet:GetSessionIdentifier(), true)
    if type(snapshots) ~= "table" then
        return false, STRINGS.PEARL.UI.CMD_ERRORS.FAILED_SNAPHOTS_LOAD
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
            return false, STRINGS.PEARL.UI.CMD_ERRORS.NO_SNAPSHOT_FOUND:format(target_day)
        end

        local reason
        local successfull = false

        TheSim:GetPersistentString(tostring(snapshot.world_file)..".meta", function(success, data)
            local cycle = getsnapshotcycle(data)
            if type(cycle) ~= "number" then
                -- successfull = false
                -- reason = STRINGS.PEARL.
                -- We should fail here as well...
            end

            if cycle == target_cycle and snapshot.snapshot_id ~= nil then
                TheWorld:PushModEvent("world_rollback_days", days, after)

                handler(true, STRINGS.PEARL.LOGS.ROLLBACK_DAYS:format(target_day))
                return PEARL.WallScheduler:ExecuteInTime(
                    after or 0, PEARL.RawRollbackByID, nil, snapshot.snapshot_id
                )
            end

            -- The snapshots are being saved in order.
            if cycle > target_cycle then
                -- Looks like this snapshot isn't the target one...
                -- Try to load the next snapshot
                return tryloadsnapshot(index + 1)
            end

            successfull = false
            reason = STRINGS.PEARL.UI.CMD_ERRORS.NO_SNAPSHOT_FOUND:format(target_day)
        end)

        return successfull, reason
    end

    -- We are starting from snapshot at index 1 which should be the newest.
    return tryloadsnapshot(1)
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
    return PEARL.CONFIG.SHARD_NAME or PEARL.GetShardFancyNameByID(PEARL.SHARDID)
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

function PEARL.GetRarityForPrefab(prefab)
    return (prefab and tonumber(PEARL.PREFABS.RARE_ITEMS[prefab])) or 0
end

function PEARL.PrefabExists(prefab)
    return PrefabExists(prefab) == true
end

function PEARL.PrefabToName(prefab)
    return STRINGS.NAMES[string.upper(prefab)] or prefab or "MISSING_NAME"
end

local TYPE_CONVERTERS = {
    ["string"] = tostring,
    ["number"] = tonumber,
    ["function"] = {
        ["string"] = loadstring,
    },
    ["table"] = {
        ["userdata"] = instrument_userdata,
    },
}
--- @return any
function PEARL.TryConvertToType(value, tp)
    local origin_type = type(value)
    if origin_type == tp then
        return value
    end

    local converterfn = TYPE_CONVERTERS[tp]
    if type(converterfn) == "table" then
        converterfn = converterfn[origin_type]
    end

    if type(converterfn) ~= "function" then
        return value
    end

    return converterfn(value) or value
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

--- @param entity string|EntityScript
--- @return string
function PEARL.GetStandardizedNameFor(entity, noprefix)
    if type(entity) ~= "table" then
        return tostring(entity)
    end

    --- For players
    if entity.userid then
        return entity:GetDisplayName()
    end

    local name = STRINGS.NAMES[string.upper(entity.prefab)] or entity:GetBasicDisplayName()
    if noprefix ~= true then
        for tagname, prefix in pairs(STRINGS.PEARL.TAG_PREFIXES) do
            if entity:HasTag(tagname) then
                name = prefix.." "..name
            end
        end
    end

    return name
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

    return grouped
end

function PEARL.GetBurnableEntitiesNearPos(pos, radius)
    return TheSim:FindEntities(pos.x, pos.y, pos.z, radius,
        PEARL.CONSTS.ENT_MUST_HAVE_TAGS,
        PEARL.CONSTS.ENT_CANT_HAVE_TAGS,
        PEARL.CONSTS.ENT_ONEOF_TAGS
    )
end

-- Runs a function and catches errors during the call.
-- Return values are the same as for calling it via xpcall function.
--
-- Note: This is not the most efficient thing so run it only
-- on places where we do not care about time.
--- @return boolean success, any result, ...
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
            return func(PEARL.unpack(args))
        end,
        function(err)
            local stacktrace = StackTrace(err) or err
            PEARL.error(
                "Error in function call:", stacktrace or "Unknown"
            )

            --- @TODO: Replace this with an event.
            -- Try to always print at least something when an error happens.
            local traceback = stacktrace or STRINGS.PEARL.REPORTS.NO_STACKTRACE
            -- This function is being used in frontend as well!
            if PEARL.DiscordReporter and PEARL.DiscordReporter:IsEnabled() then
                PEARL.DiscordReporter:ReportCatchedLuaError(traceback)
            elseif PEARL.ClientNetwork then
                PEARL.ClientNetwork:SendErrorTracebackToServer(traceback)
            end
        end
    )}

    return unpack(result)
end

--- @return integer
function PEARL.CountPrefabs(prefab)
    return c_countprefabs(prefab, true) or 0
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
    radius = radius or PEARL.CONSTS.EXTINGUISH_RADIUS
    local onfire = TheSim:FindEntities(x, y, z, radius,
        nil, -- must-have tags
        {'wildfireprotected', 'campfire', 'NOCLICK', 'FX','DECOR','INLIMBO','burnt'}, -- cant-have tags
        {'fire','smolder'} -- must-have-one tags
    )

    local count = 0
    for i = 1, #onfire do
        if onfire[i].components and onfire[i].components.burnable then
            onfire[i].components.burnable:Extinguish()

            count = count + 1
        end
    end

    return count
end
