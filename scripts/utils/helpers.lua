--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


-- This is really required!
require("stacktrace")

--- Load as little stuff here as possible since this is loaded at the start.
local EncodeBase64 = PEARL.loadfile('utils/base64encoder')
local PlayerMetadata = PEARL.loadfile("models/playermetadata")

local MARKDOWN = PEARL.loadfile("libraries/markdown")

--------------------------------

local KLEI_ENCODED_DATA_PATTERN = PEARL.CONSTS.KLEI_ENCODED_DATA_PREFIX.."%s"

-----------------------------------
-- [[ Local Functions ]]
-----------------------------------

local function FligoFilter(fligo)
    return fligo.components.machine and fligo.components.machine.ison == true
end

local function getfiltersource(src)
    return (src == nil and "[?]")
        or (src:sub(1, 1) == "@" and src:sub(2))
        or src
end

local function getformatinfo(info)
    return info ~= nil
        and string.format("@%s%s in %s",
                getfiltersource(info.source),
                info.currentline ~= nil and (":"..info.currentline) or "",
                info.name or "?")
        or "**error**"
end

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

--- @Note Make sure to always provide an existing userid!
--- @return PlayerMetadata
function PEARL.GetPlayerMetadataFor(userid, noload)
    --- @type PlayerMetadata
    local metadata = PlayerMetadata(userid)
    if noload ~= true then
        metadata:LoadPlayerData()
        metadata:LoadInventoryData()
    end

    return metadata
end

function PEARL.GetMaxStringSize(string_list, key, keyname, fn)
    if keyname ~= nil then
        key = false
    end

    local max_size = 0
    local size
    for k, v in pairs(string_list) do
        v = type(fn) == "function" and fn(k, v) or v
        if not keyname or k == keyname or (type(v) == "table" and v[keyname]) ~= nil then
            size = key and string.utf8len(tostring(k)) or (
                type(v) == "table" and v[keyname] ~= nil and string.utf8len(tostring(v[keyname]))
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
    local state = TheWorld and TheWorld.state
    local season_prefab = state and state.season
    local season_prefab_normalized = season_prefab and string.upper(season_prefab) or nil
    local remainingdaysinseason = state and state.remainingdaysinseason
    local elapseddaysinseason = state and state.elapseddaysinseason
    local season_name = STRINGS.PEARL.SEASONS[season_prefab_normalized] or STRINGS.PEARL.SEASON_UNKNOWN

    local season_prefix
    if remainingdaysinseason ~= nil and elapseddaysinseason ~= nil then
        if remainingdaysinseason * 3 <= elapseddaysinseason then
            season_prefix = STRINGS.PEARL.SEASON_PREFIX_LATE[season_prefab_normalized]
        elseif elapseddaysinseason * 3 <= remainingdaysinseason then
            season_prefix = STRINGS.PEARL.SEASON_PREFIX_EARLY[season_prefab_normalized]
        end
    end

    return (season_prefix and season_prefix.." " or "")..season_name
end

function PEARL.GetFancyCharacterPrefabFor(userid)
    local player = LookupPlayerInstByUserID(userid)
    if player then
        return player:GetFancyPrefabName()
    end

    local lastprefabfancy = PEARL.DB:GetField(userid, "lastprefabfancy")
    if lastprefabfancy and not lastprefabfancy:blank() then
        return lastprefabfancy
    end

    local client = userid and TheNet:GetClientTableForUser(userid)
    if client then
        return client.prefab or ""
    end

    return PEARL.DB:GetField(userid, "lastprefab", "")
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

--- @param kleid string
function PEARL.IsKleiIDValid(kleid)
    return type(kleid) == "string" and kleid:match(PEARL.CONSTS.KLEI_ID_PATTERN) ~= nil
end

function PEARL.TimestampToTable(timestamp)
    return timestamp and os.date("*t", timestamp)
end

--- @alias tformat
---| "%a"	# abbreviated weekday name (e.g., Wed)
---| "%A"	# full weekday name (e.g., Wednesday)
---| "%b"	# abbreviated month name (e.g., Sep)
---| "%B"	# full month name (e.g., September)
---| "%c"	# date and time (e.g., 09/16/98 23:48:10)
---| "%d"	# day of the month (16) [01-31]
---| "%H"	# hour, using a 24-hour clock (23) [00-23]
---| "%I"	# hour, using a 12-hour clock (11) [01-12]
---| "%M"	# minute (48) [00-59]
---| "%m"	# month (09) [01-12]
---| "%p"   # either "am" or "pm" (pm)
---| "%S"	# second (10) [00-61]
---| "%w"	# weekday (3) [0-6 = Sunday-Saturday]
---| "%x"	# date (e.g., 09/16/98)
---| "%X"	# time (e.g., 23:48:10)
---| "%Y"	# full year (1998)
---| "%y"	# two-digit year (98) [00-99]
---| "%%"	# the character `%

--- @param field tformat
function PEARL.GetFieldFromTimestamp(timestamp, field)
    return os.date(field, timestamp)
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

--- @return string
function PEARL.GetUserName(userid)
    local client = userid and TheNet:GetClientTableForUser(userid) or PEARL.ServerNetwork:GetCachedClientTableFor(userid)
    return client and client.name or PEARL.DB:GetField(userid, "username", userid) or "UNKNOWN"
end

--- @param prefab string
--- @param stacksize number?
function PEARL.PrefabToName(prefab, stacksize)
    local name = STRINGS.NAMES[prefab and string.upper(prefab)] or prefab or "MISSING_NAME"
    if stacksize  and stacksize > 1 then
        return STRINGS.PEARL.LOGS.ITEM:format(stacksize, name)
    end

    return name
end

local TRUE = {
    ['1'] = true,
    ['t'] = true,
    ['T'] = true,
    ['true'] = true,
    ['TRUE'] = true,
    ['True'] = true,
}
local FALSE = {
    ['0'] = false,
    ['f'] = false,
    ['F'] = false,
    ['false'] = false,
    ['FALSE'] = false,
    ['False'] = false,
}

function PEARL.toboolean(x)
    if TRUE[x] == true then
        return true;
    elseif FALSE[x] == false then
        return false;
    else
        return false, string.format('cannot convert %q to boolean', x);
    end
end

function PEARL.tointeger(x)
    if tostring(x):match("^%-?%d+$") == nil then
        return nil
    end

    return tonumber(x)
end

function PEARL.memaddr(referencable)
    return tostring(referencable):sub(type(referencable):len() + 3)
end

function PEARL.isvisiblestring(s)
    return type(s) == "string" and not s:blank()
end

local deepcopy, type = deepcopy, type
function PEARL.deepcopy(v) -- Optimized version of the in-game "deepcopy" function.
    if type(v) ~= "table" then
        return v
    end

    return deepcopy(v)
end

local TYPE_CONVERTERS = {
    ["string"] = tostring,
    ["number"] = tonumber,
    ["integer"] = PEARL.tointeger,
    ["boolean"] = PEARL.toboolean,
    ["function"] = {
        ["string"] = loadstring,
    },
    ["table"] = {
        ["userdata"] = instrument_userdata,
    },
}
--- @return boolean success, any converted
function PEARL.TryConvertToType(value, tp)
    local origin_type = type(value)
    if origin_type == tp then
        return true, value
    end

    -- For special case conversions like "string" to "function"
    local converterfn = TYPE_CONVERTERS[tp]
    if type(converterfn) == "table" then
        converterfn = converterfn[origin_type]
    end

    if type(converterfn) ~= "function" then
        PEARL.warn("No convertor exists for type", type(value), "to type", tp)
        return false, value
    end

    local new_value = converterfn(value)
    if new_value == nil then
        return false, value
    end

    return true, new_value
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

function PEARL.NetProfileLink(username, netid)
    return MARKDOWN.hlink(username, MARKDOWN.escape_link_embeds(
        PEARL.CONSTS.STEAM_ACCOUNT_URL:format(netid)
    ))
end

local missing_name_cache = {}
--- @param entity string|EntityScript
--- @return string
function PEARL.GetStandardizedNameFor(entity, noprefix)
    if not EntityScript.is_instance(entity) then
        return tostring(entity)
    end

    --- For players
    if entity.userid then
        return entity:GetDisplayName()
    end

    local name = "MISSING NAME"
    if entity.prefab then
        -- Do not call entity:GetBasicDisplayName if we have no prefab since some displaynamefns need it.
        name = STRINGS.NAMES[string.upper(entity.prefab)] or entity:GetBasicDisplayName()
    end

    if entity.name and entity.components.named and string.find(string.lower(entity.name), string.lower(name), nil, true) then
        name = entity.name -- This is for Pig Mans?
    end

    if entity.components.spellbook then
        name = entity.components.spellbook:GetSpellName() or name
    end

    if noprefix ~= true then
        for tagname, prefix in pairs(STRINGS.PEARL.TAG_PREFIXES) do
            if entity:HasTag(tagname) then
                name = prefix.." "..name
            end
        end
    end

    if entity.prefab and name == "MISSING NAME" and missing_name_cache[entity.prefab] == nil then
        missing_name_cache[entity.prefab] = true
        PEARL.DiscordReporter:SendRawReportString("Entity is MISSING NAME:\nPrefab: "..string.raw(tostring(entity.prefab)))
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

function PEARL.IsPosFireProtected(pos)
    return table.empty(PEARL.GetEntitiesNearPos(pos, TUNING.FIRE_DETECTOR_RANGE, {
        "hasemergencymode", "structure",
    }, nil, nil, FligoFilter)) == false
end

function PEARL.GetEntitiesNearPos(pos, radius, musttags, canttags, mustoneoftags, filterfn)
    local entities = TheSim:FindEntities(
        pos.x, pos.y, pos.z, radius, musttags, canttags, mustoneoftags
    ) or {}

    return type(filterfn) == "function" and table.filter(entities, function(k, v)
        return v and (not filterfn or filterfn(v))
    end) or entities
end

function PEARL.GetBurnableEntitiesNearPos(pos, radius, ...)
    return PEARL.GetEntitiesNearPos(pos, radius,
        PEARL.CONSTS.ENT_MUST_HAVE_TAGS,
        PEARL.CONSTS.ENT_CANT_HAVE_TAGS,
        PEARL.CONSTS.ENT_ONEOF_TAGS,
        ...
    )
end

function PEARL.HandleError(err)
    local stacktrace = StackTrace(err) or err
    PEARL.error(
        "Catched lua error:", stacktrace or "Unknown"
    )

    --- @TODO: Replace this with an event.
    -- Try to always print at least something when an error happens.
    local traceback = stacktrace or STRINGS.PEARL.REPORTS.NO_STACKTRACE
    -- This function is being used in frontend as well!
    if PEARL.DiscordReporter and PEARL.DiscordReporter:IsEnabled() then
        PEARL.DiscordReporter:ReportCatchedLuaError(traceback)
    elseif PEARL.ClientNetwork then
        PEARL.ClientNetwork:SendErrorTracebackToServer(traceback, true)
    end
end

function PEARL.CalledFrom(level) -- Level 3 by default
    local info = debug.getinfo(level or 3)
    return getformatinfo(info)
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
        PEARL.HandleError
    )}

    return unpack(result)
end

--- @return integer
function PEARL.CountPrefabs(prefab)
    local count = 0
    for _, ent in pairs(Ents) do
        if ent.prefab == prefab and ent:IsValid() and (not ent.components.health or not ent.components.health:IsDead()) then
            count = count + 1
        end
    end

    return count
end

function PEARL.ToISO8601UTC(timestamp)
    -- This is used when sending timestamps to external services (like discord)
    -- which require this format. Such services want the time in UTC so they can
    -- display it for each client according to their timezone.
    --
    -- "!" for UTC time
    return tostring(os.date("!%Y-%m-%dT%X", timestamp))
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
