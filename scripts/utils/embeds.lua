--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



--- @type Embed
local Embed = PEARL.loadfile("libraries/discordapi/models/embed")

local MARKDOWN = PEARL.loadfile("libraries/markdown")

local TEMPLATES = require("widgets/redux/templates")
local Customize = require("map/customize")

-------------------------------------
-- [[ Constants ]]
-------------------------------------

local MAX_MODNAME_LEN = 32
local MAX_MODID_LEN = 16

-------------------------------------
-- [[ Declaration ]]
-------------------------------------

local EMBEDS = {}

-------------------------------------
-- [[ Embed Builders ]]
-------------------------------------

--- @param pmd PlayerMetadata
--- @return Embed
function EMBEDS.Inventory(pmd, highlighted)
    local userid    = pmd:GetUserID()
    local name      = pmd:GetName() or PEARL.DB:GetField(userid, "name") or ""
    local inventory = pmd:GetInventory()
    local prefab    = PEARL.DB:GetField(userid, "fancyprefab", pmd:GetPrefab())
    local age       = pmd:GetAge()
    local netid     = pmd:GetNetID()
    local url       = netid and PEARL.CONSTS.STEAM_ACCOUNT_URL:format(netid)

    local description = ""
    local max_prefab_size = PEARL.GetMaxStringSize(inventory, true)
    local max_count_size = PEARL.GetMaxStringSize(inventory)

    for iprefab, icount in pairs(inventory) do
        icount = tostring(icount)
        local line = MARKDOWN.codeline(string.rep(" ", max_count_size - #icount)..icount.."x").." "..
        MARKDOWN.codeline(iprefab..string.rep(" ", max_prefab_size - #iprefab))

        local icon = PEARL.ICONS.INVENTORY[iprefab]
        if icon then
            line = line.." "..icon
        end

        line = line.." "..PEARL.PrefabToName(iprefab)

        -- Keep the highlighted items on top.
        if type(highlighted) == "table" and type(highlighted[iprefab]) == "number" and highlighted[iprefab] >= 1 then
            description = MARKDOWN.bold(line).."\n"..description
        else
            description = description..line.."\n"
        end
    end

    if #description <= 0 then
        description = STRINGS.PEARL.EMBEDS.INV.INVENTORY_EMPTY
    else
        description = STRINGS.PEARL.EMBEDS.INV.INVENTORY.."\n"..description
    end

    local icon = PEARL.ICONS.PLAYER_PREFABS[prefab] or PEARL.ICONS.PLAYER_PREFABS[""]

    --- @type Embed
    local embed = Embed()
    embed:SetTitle(STRINGS.PEARL.EMBEDS.INV.TITLE:format(
        icon, name, userid
    ), url)
    embed:SetDescription(description)
    embed:SetTimestamp(os.time())

    -- The age field seems to be a bit weird here...
    embed:AddField(STRINGS.PEARL.EMBEDS.INV.FD_NAMES.SURVIVED, STRINGS.PEARL.EMBEDS.INV.SURVIVED:format(
        age and age or "?", TheWorld and TheWorld.state.cycles + 1 or "?"
    ))

    return embed
end

function EMBEDS.SuspiciousInventory(pwd, suspiciousness)
    -- Highlight rare items
    local embed = EMBEDS.Inventory(pwd, PEARL.PREFABS.RARE_ITEMS)
    if type(suspiciousness) == "number" then
        embed:AddField(
            STRINGS.PEARL.EMBEDS.INV.FD_NAMES.SUSPICIOUSNESS,
            MARKDOWN.codeline(tostring(math.floor(suspiciousness * 100)).."%"),
            true
        )
    end

    return embed
end

function EMBEDS.LeaderboardArchived()
    return Embed()
        :SetTitle(STRINGS.PEARL.EMBEDS.LEADERBOARD.TITLE_ARCHIVED)
        :SetColor(Embed.COLORS.LIGHT_GREY)
end

--- @param leaderboard Leaderboard
function EMBEDS.Leaderboard(leaderboard, monthly)
    local data = leaderboard:GetData()
    --- @type Embed
    local embed = Embed()
        :SetTitle(STRINGS.PEARL.EMBEDS.LEADERBOARD[monthly and "TITLE_CUR" or "TITLE_ABS"])
        :SetThumbnail(STRINGS.PEARL.EMBEDS.LEADERBOARD[monthly and "THMB_CUR_URL" or "THMB_ABS_URL"])
        :SetTimestamp(os.time())

    if not leaderboard:HasEnoughPlayers() then
        embed:SetDescription(STRINGS.PEARL.EMBEDS.LEADERBOARD.NOT_ENOUGH_DATA)
    else
        local max_rep_len = 0
        local index_col, name_col, rep_col = "", "", ""
        for i, userid in ipairs(data.players) do
            local name = tostring(PEARL.DB:GetField(userid, "username") or "UNKNOWN")
            local netid = PEARL.DB:GetField(userid, "netid") or nil
            local rep = tostring(PEARL.Reputation:GetFieldOf(userid, monthly and "monthgains" or "value"))

            if i == 1 then
                max_rep_len = #rep
            end

            -- This fixes the indexes text for centering
            local index = PEARL.ICONS.LEADERBOARD_PLACES[i] or MARKDOWN.initspacing(tostring(i), 1, 2)
            index_col = index_col..index.."\n"
            name_col = name_col..MARKDOWN.hlink(
                MARKDOWN.codeline(tostring(name)), netid and PEARL.CONSTS.STEAM_ACCOUNT_URL:format(netid) or nil
            ).."\n"

            local rep_fd_len = #STRINGS.PEARL.EMBEDS.LEADERBOARD.FD_NAMES.REP_COL
            local hairs = (rep_fd_len - #rep) * 3 + (max_rep_len - #rep) * 4
            rep_col = rep_col..MARKDOWN.initspacing(MARKDOWN.codeline(rep), 0, hairs).."\n"
        end

        embed:AddField(STRINGS.PEARL.EMBEDS.LEADERBOARD.FD_NAMES.INDEX_COL, index_col, true)
        embed:AddField(STRINGS.PEARL.EMBEDS.LEADERBOARD.FD_NAMES.NAME_COL, name_col, true)
        embed:AddField(STRINGS.PEARL.EMBEDS.LEADERBOARD.FD_NAMES.REP_COL, rep_col, true)

        if data.dayleader then
            local netid = PEARL.DB:GetField(data.dayleader, "netid")
            local username = tostring(PEARL.DB:GetField(data.dayleader, "username") or "UNKNOWN")
            local gains = PEARL.Reputation:GetTodayGainsOf(data.dayleader)
            local reputation = PEARL.Reputation:GetOf(data.dayleader)
            local percent = math.round(gains / reputation, 4) * 100

            embed:AddField("Hráč Dňa", string.format("%s %s +%s (%s%%)",
                PEARL.ICONS.GAINS, MARKDOWN.hlink(
                MARKDOWN.codeline(tostring(username)), netid and PEARL.CONSTS.STEAM_ACCOUNT_URL:format(netid) or nil
            ), gains, percent))
        end
    end

    local date = data.monthstart or data.timecreated
    if date then
        local date_tbl = PEARL.TimestampToTable(date)
        local month_name = PEARL.GetMonthFancyName(date_tbl.month)
        local fd_name = monthly and STRINGS.PEARL.EMBEDS.LEADERBOARD.FD_NAMES.MONTH or STRINGS.PEARL.EMBEDS.LEADERBOARD.FD_NAMES.CREATED
        embed:AddField(
            fd_name, MARKDOWN.codeblock(
                STRINGS.PEARL.FULL_MONTH_NAME:format(month_name, date_tbl.year)
            ), false
        )
    end

    local local_count = leaderboard:HasEnoughPlayers() and #data.players or 0
    local total_count = math.max(local_count, tonumber(data.recordcount) or PEARL.DB:GetTotalRecordCount())
    embed:SetFooter(("%s/%s"):format(local_count, total_count))

    return embed
end

--- @return Embed
function EMBEDS.ServerBoot()
    local seed = TheWorld and TheWorld.meta and TheWorld.meta.seed or "???"
    local active_event = GetFirstActiveSpecialEvent() or "none"

    return Embed()
        :SetTitle(STRINGS.PEARL.EMBEDS.STARTUP.TITLE)
        :SetColor(Embed.COLORS.GREEN)
        :SetThumbnail(STRINGS.PEARL.EMBEDS.STARTUP.THMB_URL)
        :SetTimestamp(os.time())

        :AddField(STRINGS.PEARL.EMBEDS.STARTUP.FD_NAMES.PLATFORM, MARKDOWN.codeline(PLATFORM), true)
        :AddField(STRINGS.PEARL.EMBEDS.STARTUP.FD_NAMES.MOD_V, MARKDOWN.codeline(PEARL.MOD_INFO.version), true)
        :AddField(STRINGS.PEARL.EMBEDS.STARTUP.FD_NAMES.GAME_V, MARKDOWN.codeline(TEMPLATES.GetBuildString()), true)
        :AddField(STRINGS.PEARL.EMBEDS.STARTUP.FD_NAMES.SEED, MARKDOWN.codeline(seed), true)
        :AddField(STRINGS.PEARL.EMBEDS.STARTUP.FD_NAMES.PLAYSTYLE, MARKDOWN.codeline(TheNet:GetServerGameMode()), true)
        :AddField(STRINGS.PEARL.EMBEDS.STARTUP.FD_NAMES.EVENT, STRINGS.UI.SPECIAL_EVENT_NAMES[string.upper(active_event)] or STRINGS.PEARL.LOGS.NONE_EVENT, true)
end

--- @return Embed
function EMBEDS.WorldRegen(world, session_id)
    world = world or TheWorld
    session_id = session_id or TheNet:GetSessionIdentifier() or "???"
    local seed = world and world.meta and world.meta.seed or "???"
    local save_version = world and world.meta and world.meta.generated_on_saveversion or "???"

    local is_master = world.worldprefab == "forest"
    local default_world_settings = Customize.GetWorldSettingsOptionsWithLocationDefaults(world.worldprefab, is_master)
    local default_world_gen_options = Customize.GetWorldGenOptionsWithLocationDefaults(world.worldprefab, is_master)
    local customizations = JoinArrays(default_world_settings, default_world_gen_options)

    local displayed = {}
    local displayed_count = 0
    local max_displayed = 10 * 2 -- For generation options and world setting
    for i, customization in ipairs(customizations) do
        local override = world.topology.overrides[customization.name] or customization.default
        if override ~= customization.default then
            displayed[customization.name] = override
            displayed_count = displayed_count + 1

            if displayed_count >= max_displayed then
                break
            end
        end
    end

    local description = ""
    if not table.empty(displayed) then
        local max_key_len = PEARL.GetMaxStringSize(displayed, true)

        for name, value in pairs(displayed) do
            local spacing = max_key_len - #name
            description = description..name..string.rep(" ", spacing).." = "..value.."\n"
        end

        if #displayed < #customizations then
            description = description.."... ("..STRINGS.PEARL.EMBEDS.REGEN.OTHER:format(
                table.size(customizations) - displayed_count
            )..")\n"
        end

        description = STRINGS.PEARL.EMBEDS.REGEN.DESC_TITLE..MARKDOWN.codeblock(description, "ini")
    end

    return Embed()
        :SetTitle(STRINGS.PEARL.EMBEDS.REGEN.TITLE:format(PEARL.GetShardFancyName()))
        :SetColor(Embed.COLORS.GREEN)
        :SetThumbnail(STRINGS.PEARL.EMBEDS.REGEN.THMB_URL)
        :SetDescription(description)
        :SetTimestamp(os.time())

        :AddField(STRINGS.PEARL.EMBEDS.REGEN.FD_NAMES.SEED, MARKDOWN.codeline(seed), true)
        :AddField(STRINGS.PEARL.EMBEDS.REGEN.FD_NAMES.SESSION_ID, MARKDOWN.codeline(session_id), true)
        :AddField(STRINGS.PEARL.EMBEDS.REGEN.FD_NAMES.SAVE_VERSION, MARKDOWN.codeline(save_version), true)
        :AddField(STRINGS.PEARL.EMBEDS.REGEN.FD_NAMES.REED_TRAP, tostring(PEARL.CheckForReedTrap() and 1 or 0), true)
        :AddField(STRINGS.PEARL.EMBEDS.REGEN.FD_NAMES.WALRUS_CAMPS, tostring(PEARL.CountPrefabs("walrus_camp")), true)
end

--- @return Embed
function EMBEDS.ClientMods(enabled_mods, owner_name)
    local modlist = type(enabled_mods.list) == "table" and enabled_mods.list or {}
    local description = ""
    local max_id_size = PEARL.GetMaxStringSize(modlist, false, "id")

    -- Data processed here are untrusted.
    for _, mod in pairs(modlist) do
        local type_icon = mod.private and PEARL.ICONS.LOCAL or PEARL.ICONS.STEAM
        local state_icon = mod.allowed and PEARL.ICONS.CHECK or PEARL.ICONS.X
        local fancyname = MARKDOWN.bold(type(mod.fancyname) == "string" and mod.fancyname:ltake(MAX_MODNAME_LEN, nil, "...") or "???")

        local modid = ""
        if not mod.private then
            modid = type(mod.id) == "string" and mod.id:ltake(MAX_MODID_LEN) or "???"
            local modid_spac = string.rep(" ", max_id_size - #mod.id)
            modid = MARKDOWN.codeline(modid..modid_spac)
            modid = (MARKDOWN.hlink(
                modid, PEARL.CONSTS.STEAM_WORKSHOP:format(tostring(mod.id):ltake(MAX_MODID_LEN, nil, "..."))
            ).." ")
        else
            modid = MARKDOWN.codeline(string.rep(" ", max_id_size)).." "
        end

        description = description..type_icon.." "..state_icon.." "..modid..(
            mod.allowed and fancyname or MARKDOWN.strikethrough(fancyname)
        )

        description = description.."\n"
    end

    if description ~= "" and PEARL.CONFIG.MOD_BLOCKER.ALLOWLIST == true then
        description = description.."\n"..PEARL.ICONS.ANNOUNCEMENTS["default"].." "..STRINGS.PEARL.EMBEDS.MODS.ALLOWLIST
    end

    local shown_count = table.size(modlist)
    return Embed()
        :SetTitle(STRINGS.PEARL.EMBEDS.MODS.TITLE:format(MARKDOWN.codeline(owner_name)))
        :SetColor(Embed.COLORS.RED)
        :SetTimestamp(os.time())
        :SetDescription(description)
        :SetFooter(STRINGS.PEARL.EMBEDS.MODS.FOOTER:format(shown_count, enabled_mods.count or shown_count))
end

--- @TODO: Add more info
--- @return Embed
function EMBEDS.ClientProfile(userid, dbr)
    local P_STRINGS = STRINGS.PEARL.EMBEDS.PROFILE

    local prefab = dbr.lastprefabfancy or dbr.lastprefab or ""
    local icon = PEARL.ICONS.PLAYER_PREFABS[prefab]

    -- The locale may not be allowed as of now.
    local loc = dbr.allowedlocale or dbr.lastlocale
    local loc_allowed = PEARL.ServerNetwork:IsLocaleAllowed(loc)
    local loc_icon = loc and ":flag_"..string.lower(loc)..":"
    local loc_str = STRINGS.PEARL.LOGS.TAG:format(
        STRINGS.PEARL.UI[loc_allowed and "ALLOWED" or "BLOCKED"]
    )

    local last_seen_time = MARKDOWN.timestamp(dbr.lastseentime)
    if PEARL.ServerNetwork:IsClientConnected(userid) then
        last_seen_time = PEARL.ICONS.ONLINE.." "..P_STRINGS.PLAYING
    end

    local embed = Embed()
        :SetTitle(P_STRINGS.TITLE:format(icon, dbr.username or "UNKNOWN"))
        :SetUrl(PEARL.CONSTS.STEAM_ACCOUNT_URL:format(dbr.netid))
        :SetColor(Embed.COLORS.BLUE)
        :SetThumbnail(dbr.avatar)
        :AddField(P_STRINGS.FD_NAMES.PLAYED, MARKDOWN.codeline(dbr.totaldays), true)
        :AddField(P_STRINGS.FD_NAMES.REP, MARKDOWN.codeline(dbr.reputation.value), true)
        :AddField(P_STRINGS.FD_NAMES.SEEN, last_seen_time, true)
        :AddField(P_STRINGS.FD_NAMES.LOCALE, loc_icon and loc_icon.." "..loc_str or "UNKNOWN", true)
        :SetFooter(P_STRINGS.FOOTER:format(userid, dbr.netid, dbr.rootuserid or "UNKNOWN"))

    if dbr[PEARL.DB.BINDING_FIELD[PEARL.DB.BINDING_TYPE.DISCORD]] then
        embed:AddField(P_STRINGS.FD_NAMES.DISCORD, MARKDOWN.mention(dbr.discordid, MARKDOWN.MENTION_TYPE.USER), true)
    end

    return embed
end

-------------------------------------
-- [[ Return ]]
-------------------------------------

return EMBEDS
