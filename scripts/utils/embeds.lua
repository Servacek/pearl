--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
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

local SPACE = " "

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
    local userid     = pmd:GetUserID()
    local owner_name = PEARL.DB:GetField(userid, "username", pmd:GetName()) or userid
    local inventory  = pmd:GetInventory()
    local prefab     = PEARL.DB:GetField(userid, "fancyprefab", pmd:GetPrefab())
    -- local age        = pmd:GetAge()
    local netid      = PEARL.DB:GetField(userid, "netid", pmd:GetNetID())
    local url        = netid and PEARL.CONSTS.STEAM_ACCOUNT_URL:format(netid)

    local description = ""
    local max_count_size, max_prefab_size, line_spacing

    -- local i = 1
    local lines = {}
    local inv_l = table.size(inventory)
    -- local inlining = inv_l > 4
    local inv_l_half = math.ceil(inv_l / 2)
    -- local max_name_size = 0
    for iprefab, icount in metapairs(inventory) do
        icount = tostring(icount)
        max_count_size = max_count_size or PEARL.GetMaxStringSize(inventory)
        local line = MARKDOWN.codeline(string.rep(" ", max_count_size - #icount)..icount.."x").." "

        if PEARL.CONFIG.INVENTORY_ICONS then
            local icon = PEARL.ICONS.INVENTORY[iprefab]
            if icon then
                line = line..icon
            end
        else
            max_prefab_size = max_prefab_size or PEARL.GetMaxStringSize(inventory, true)
            -- Show at least the prefab...
            line = line..MARKDOWN.codeline(iprefab..string.rep(" ", max_prefab_size - #iprefab))
        end

        local highlight = type(highlighted) == "table" and type(highlighted[iprefab]) == "number" and highlighted[iprefab] >= 1
        local name = PEARL.PrefabToName(iprefab)
        -- local name_size = string.utf8len(name)
        if highlight then
            name = MARKDOWN.bold(name)
        end

        line = line.." "..name

        -- if inlining then
        --     if i > inv_l_half then
        --         line_spacing = line_spacing or string.rep(" ", max_name_size - name_size)
        --         print("LINE SPACING...", string.raw(line_spacing))
        --     elseif name_size > max_name_size then
        --         max_name_size = name_size
        --     end
        -- end

        -- Keep the highlighted items on top.
        if highlight then
            -- if i >= inv_l_half and inlining then
            --     line = line..line_spacing..lines[inv_l_half]
            --     table.remove(lines, inv_l_half)
            -- end

            table.insert(lines, 1, line)
        else
            -- if i > inv_l_half and inlining then
            --     local line_index = i - inv_l_half
            --     table.dump(lines[line_index]:strip():split(" "))
            --     print("NAME:", lines[line_index]:split(" ")[3], string.utf8len(lines[line_index]:split(" ")[3]), max_name_size)
            --     local spacing = string.rep(" ", max_name_size - name_size)
            --     print("SPACING", string.raw(spacing))
            --     lines[line_index] = lines[line_index]..spacing..line
            -- else
                lines[#lines+1] = line
            --end
        end

        -- i = i + 1
    end

    local col1, col2 = "", ""
    for j = 1, inv_l_half do
        col1 = col1.."\n"..lines[j]

        local line2 = lines[j + inv_l_half]
        if line2 then
            col2 = col2.."\n"..line2
        end
    end
    --description = table.concat(lines, "\n")

    if col1:blank() then
        col1 = STRINGS.PEARL.EMBEDS.INV.INVENTORY_EMPTY
    end

    --local icon = PEARL.ICONS.PLAYER_PREFABS[prefab] or PEARL.ICONS.PLAYER_PREFABS[""]

    --- @type Embed
    local embed = Embed()
    embed:SetTitle(STRINGS.PEARL.EMBEDS.INV.TITLE:format(MARKDOWN.codeline(owner_name)), url)
    embed:SetDescription(description)
    embed:SetTimestamp(os.time())
    embed:SetFooter(userid)
    embed:SetThumbnail(STRINGS.PEARL.EMBEDS.INV.THMB_URL)
    embed:AddField("", col1, true)
    if not col2:blank() then
        embed:AddField("", col2, true)
    end

    -- The age field seems to be a bit weird here...
    -- embed:AddField(STRINGS.PEARL.EMBEDS.INV.FD_NAMES.SURVIVED, STRINGS.PEARL.EMBEDS.INV.SURVIVED:format(
    --     age and age or "?", TheWorld and TheWorld.state.cycles + 1 or "?"
    -- ))

    return embed
end

function EMBEDS.SuspiciousInventory(pwd)
    -- Highlight rare items
    local embed = EMBEDS.Inventory(pwd, PEARL.PREFABS.RARE_ITEMS)
    -- if type(suspiciousness) == "number" then
    --     embed:AddField(
    --         STRINGS.PEARL.EMBEDS.INV.FD_NAMES.SUSPICIOUSNESS,
    --         MARKDOWN.codeline(tostring(math.floor(suspiciousness * 100)).."%"),
    --         true
    --     )
    -- end

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
    local displayed = 0
    --- @type Embed
    local embed = Embed()
        :SetTitle(STRINGS.PEARL.EMBEDS.LEADERBOARD[monthly and "TITLE_CUR" or "TITLE_ABS"])
        :SetThumbnail(STRINGS.PEARL.EMBEDS.LEADERBOARD[monthly and "THMB_CUR_URL" or "THMB_ABS_URL"])
        :SetTimestamp(os.time())

    if not leaderboard:HasEnoughPlayers() then
        embed:SetDescription(MARKDOWN.italic(
            STRINGS.PEARL.EMBEDS.LEADERBOARD.NOT_ENOUGH_DATA
        ))
    else
        local max_rep_len = 0
        displayed = math.min(leaderboard:GetLength(), leaderboard:GetDisplayCount())
        local index_col, name_col, rep_col = "", "", ""
        for i = 1, displayed do
            local userid = leaderboard:GetPlayerOnPosition(i)
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
                PEARL.ICONS.ARROW_UP, MARKDOWN.hlink(
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

    local total_count = leaderboard:GetLength()
    embed:SetFooter(("%s/%s"):format(displayed, math.max(total_count, displayed)))

    return embed
end

--- @TODO: Try to replace the embed with a rank card image.
-- function EMBEDS.PlayerStats(userid)
--     local STRINGS = STRINGS.PEARL.EMBEDS.STATS
--     return Embed()
-- end

--- @return Embed
function EMBEDS.ServerInfo(boot)
    local seed = TheWorld and TheWorld.meta and TheWorld.meta.seed or "???"
    local active_event = GetFirstActiveSpecialEvent() or "none"
    local title = boot == true and STRINGS.PEARL.EMBEDS.SERVER.BOOT or STRINGS.PEARL.EMBEDS.SERVER.TITLE
    local colour = boot == true and Embed.COLORS.GREEN or Embed.COLORS.DARK_GREY
    local modv = MARKDOWN.codeline(tostring(PEARL.MOD_INFO.version))
    if PEARL.IS_BACKUP then
        modv = MARKDOWN.bold(STRINGS.PEARL.UI.BACKUP_TAG).."\n"..modv
    end

    return Embed()
        :SetAuthor(TheNet:GetServerName())
        :SetTitle(title)
        :SetColor(colour)
        :SetThumbnail(STRINGS.PEARL.EMBEDS.SERVER.THMB_URL)
        :SetTimestamp(os.time())

        :AddField(STRINGS.PEARL.EMBEDS.SERVER.FD_NAMES.PLATFORM, MARKDOWN.codeline(PLATFORM), true)
        :AddField(STRINGS.PEARL.EMBEDS.SERVER.FD_NAMES.MOD_V, modv, true)
        :AddField(STRINGS.PEARL.EMBEDS.SERVER.FD_NAMES.GAME_V, MARKDOWN.codeline(TEMPLATES.GetBuildString()), true)
        :AddField(STRINGS.PEARL.EMBEDS.SERVER.FD_NAMES.SEED, MARKDOWN.codeline(seed), true)
        :AddField(STRINGS.PEARL.EMBEDS.SERVER.FD_NAMES.PLAYSTYLE, MARKDOWN.codeline(TheNet:GetServerGameMode()), true)
        :AddField(STRINGS.PEARL.EMBEDS.SERVER.FD_NAMES.EVENT, STRINGS.UI.SPECIAL_EVENT_NAMES[string.upper(active_event)] or STRINGS.PEARL.LOGS.NONE_EVENT, true)
end

--- @return Embed
function EMBEDS.PlayerInfo()
    if TheShard:IsSecondary() then
        PEARL.warn("Created Player Info Embed on a secondary shard!")
    end

    local shardids = deepcopy(PEARL.ServerNetwork:GetConnectedShardIDs())
    local max_index_size, max_name_size, max_rep_size, max_tdays_size, max_cdays_size, max_ping_size
    local description = ""
    local clients = PEARL.ServerNetwork:GetConnectedClients()
    local shard_player_map = {}
    for i, client in pairs(clients) do
        local userid = client.userid
        local shardid = PEARL.DB:GetField(userid, "lastshardid", (
            (PEARL.ServerNetwork:IsClientConnected(userid) and not PEARL.ServerNetwork:IsClientJoining(userid) and shardids[1])
            or SHARDID.MASTER
        ))
        if not (shardid == SHARDID.MASTER or PEARL.ServerNetwork:IsShardConnected(shardid)) then
            shardid = SHARDID.MASTER
        end

        local icons = ""
        local prefab = PEARL.GetFancyCharacterPrefabFor(userid)
        local name = client.name
        local netid = client.netid
        local cur_days = tostring(client.playerage)
        local tot_days = PEARL.DB:IsEnabled() and tostring(PEARL.DB:GetField(client.userid, "totaldays")) or "???"
        local ping = tostring(client.netscore or "???")
        local rep = PEARL.DB:IsEnabled() and PEARL.Reputation:GetOf(userid)

        max_index_size = max_index_size or PEARL.GetMaxStringSize(clients, true)
        max_name_size = max_name_size or PEARL.GetMaxStringSize(clients, nil, "name")
        max_ping_size = max_ping_size or PEARL.GetMaxStringSize(clients, nil, "netscore")
        max_cdays_size = max_cdays_size or PEARL.GetMaxStringSize(clients, nil, "playerage")
        max_tdays_size = max_tdays_size or PEARL.GetMaxStringSize(clients, nil, nil, function(k, v)
            return PEARL.DB:IsEnabled() and PEARL.DB:GetField(userid, "totaldays") or ""
        end)
        max_rep_size = max_rep_size or PEARL.GetMaxStringSize(clients, nil, nil, function(k, v)
            return PEARL.DB:IsEnabled() and PEARL.Reputation:GetOf(v.userid) or ""
        end)

        local istr = tostring(i)
        local index_str = MARKDOWN.codeline(
            STRINGS.PEARL.POSITION:format(string.rep(" ", max_index_size - #istr)..istr)
        )

        local record = PEARL.DB:GetRecordFor(userid)
        if client.admin then
            icons = icons.." "..PEARL.ICONS.ADMIN
        elseif record and record:IsNovice() then
            icons = icons.." "..PEARL.ICONS.BEGINNER
        end

        if PEARL.ServerNetwork:IsClientInactive(userid) then
            icons = icons.." "..PEARL.ICONS.AFK
        end

        --- @NOTE: The spaces are only visible in codelines!
        shard_player_map[shardid] = (shard_player_map[shardid] and shard_player_map[shardid].."\n" or "")
            .."> "..index_str
            .." "..(PEARL.ICONS.PLAYER_PREFABS[prefab] or PEARL.ICONS.PLAYER_PREFABS.unknown)
            .." "..PEARL.NetProfileLink(MARKDOWN.codeline(name..string.rep(" ", max_name_size - #name)), netid)
            .." "..MARKDOWN.codeline(userid) -- userids are all the same length
            .." "..MARKDOWN.codeline(STRINGS.PEARL.PROPORTION:format(
                SPACE:rep(max_cdays_size - #cur_days)..cur_days, tot_days..SPACE:rep(max_tdays_size - #tot_days)
            ))
            .." "..MARKDOWN.codeline(SPACE:rep(max_ping_size - #ping)..ping.." ms")
            .." "..(rep and MARKDOWN.codeline(SPACE:rep(max_rep_size - #tostring(rep))..tostring(rep).." rep") or "")
            ..icons
    end

    table.insert(shardids, PEARL.SHARDID)
    table.sort(shardids, function(a, b)
        return (tonumber(a) or 0) > (tonumber(b) or 0)
    end)

    for _, shardid in ipairs(shardids) do
        local players_str = shard_player_map[tostring(shardid)]
        if players_str and not players_str:blank() then
            local shardname = STRINGS.PEARL.EMBEDS.PLAYERS.SHARD_NAME:format(
                PEARL.GetShardFancyNameByID(shardid), MARKDOWN.codeline(shardid)
            )
            description = description.."\n\n"..MARKDOWN.bold(shardname).."\n"..players_str
        end
    end

    if description:blank() then
        description = STRINGS.PEARL.EMBEDS.PLAYERS.EMPTY
    end

    return Embed()
        :SetAuthor(TheNet:GetServerName(), nil, STRINGS.PEARL.EMBEDS.PLAYERS.AUTHOR_ICON_URL)
        :SetTitle(STRINGS.PEARL.EMBEDS.PLAYERS.TITLE)
        --:SetColor(Embed.COLORS.YELLOW)
        --:SetThumbnail(STRINGS.PEARL.EMBEDS.PLAYERS.THMB_URL)
        :SetDescription(description)
        :SetTimestamp(os.time())
        :SetFooter(STRINGS.PEARL.PROPORTION:format(
            #clients, TheNet:GetDefaultMaxPlayers()
        ))
end

--- @return Embed
function EMBEDS.WorldInfo(world, session_id, regen)
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
    for _, customization in ipairs(customizations) do
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
            description = description.."... ("..STRINGS.PEARL.EMBEDS.WORLD.OTHER:format(
                table.size(customizations) - displayed_count
            )..")\n"
        end

        description = STRINGS.PEARL.EMBEDS.WORLD.DESC_TITLE..MARKDOWN.codeblock(description, "ini")
    end

    local title = regen == true and STRINGS.PEARL.EMBEDS.WORLD.REGENERATED or STRINGS.PEARL.EMBEDS.WORLD.TITLE
    local embed = Embed()
        :SetAuthor(TheNet:GetServerName(), nil, STRINGS.PEARL.EMBEDS.WORLD.AUTHOR_ICON_URL)
        :SetTitle(title:format(PEARL.GetShardFancyName()))
        :SetColor(Embed.COLORS.GREEN)
        :SetThumbnail(STRINGS.PEARL.EMBEDS.WORLD.THMB_URL)
        :SetDescription(description)
        :SetTimestamp(os.time())

        :AddField(STRINGS.PEARL.EMBEDS.WORLD.FD_NAMES.SEED, MARKDOWN.codeline(seed), true)
        :AddField(STRINGS.PEARL.EMBEDS.WORLD.FD_NAMES.SESSION_ID, MARKDOWN.codeline(session_id), true)
        :AddField(STRINGS.PEARL.EMBEDS.WORLD.FD_NAMES.SAVE_VERSION, MARKDOWN.codeline(save_version), true)

    if TheShard:IsMaster() then
        embed:AddField(STRINGS.PEARL.EMBEDS.WORLD.FD_NAMES.REED_TRAP, tostring(PEARL.CheckForReedTrap() and 1 or 0), true)
        embed:AddField(STRINGS.PEARL.EMBEDS.WORLD.FD_NAMES.WALRUS_CAMPS, tostring(PEARL.CountPrefabs("walrus_camp")), true)
    end

    return embed
end

--- @return Embed
function EMBEDS.ClientMods(enabled_mods, userid)
    local client = PEARL.ServerNetwork:GetCachedClientTableFor(userid) or TheNet:GetClientTableForUser(userid)
    local owner_name = client and client.name or PEARL.DB:GetField(userid, "username", userid)
    local modlist = type(enabled_mods.list) == "table" and enabled_mods.list or {}
    local description = ""
    local max_id_size = PEARL.GetMaxStringSize(modlist, false, "id")

    local loc_mods, pub_mods

    -- Data processed here are untrusted.
    for _, mod in pairs(modlist) do
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
        end

        local line = "> "..state_icon.." "..modid..(
            mod.allowed and fancyname or MARKDOWN.strikethrough(fancyname)
        ).."\n"

        if mod.private then
            loc_mods = (loc_mods or "")..line
        else
            pub_mods = (pub_mods or "")..line
        end
    end

    if loc_mods then
        description = description.."\n"..PEARL.ICONS.LOCAL.." "
            ..MARKDOWN.bold(STRINGS.PEARL.EMBEDS.MODS.LOC_MODS).."\n"
            ..loc_mods
    end

    if pub_mods then
        description = description.."\n"..PEARL.ICONS.STEAM.." "
            ..MARKDOWN.bold(STRINGS.PEARL.EMBEDS.MODS.PUB_MODS).."\n"
            ..pub_mods
    end

    if description ~= "" and PEARL.CONFIG.MOD_BLOCKER.ALLOWLIST == true then
        description = description.."\n"..PEARL.ICONS.ANNOUNCEMENTS["default"].." "..STRINGS.PEARL.EMBEDS.MODS.ALLOWLIST
    end

    local shown_count = table.size(modlist)
    local footer = STRINGS.PEARL.EMBEDS.MODS.FOOTER:format(shown_count, enabled_mods.count or shown_count)
    if owner_name ~= userid then
        -- Make sure we also provide the userid if not in the title.
        footer = footer.." "..Embed.FOOTER_SEPARATOR.." "..userid
    end

    return Embed()
        :SetTitle(STRINGS.PEARL.EMBEDS.MODS.TITLE:format(MARKDOWN.codeline(owner_name)))
        :SetColor(Embed.COLORS.RED)
        :SetTimestamp(os.time())
        :SetThumbnail(STRINGS.PEARL.EMBEDS.MODS.THMB_URL)
        :SetDescription(description)
        :SetFooter(footer)
end

--- @return Embed
function EMBEDS.ClientProfile(userid, dbr, all)
    dbr = dbr or PEARL.DB:GetRecordFor(userid)

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

    local last_seen_time
    if PEARL.ServerNetwork:IsClientConnectedAny(userid) then
        last_seen_time = PEARL.ICONS.ONLINE.." "..P_STRINGS.PLAYING
    elseif dbr.lastseentime ~= nil then
        last_seen_time = MARKDOWN.timestamp(dbr.lastseentime)
    else
        last_seen_time = P_STRINGS.UNKNOWN
    end

    local gametime = PEARL.Reputation:GetGamePlayTime(userid) or PEARL.Reputation:GetLocalGamePlayTime(userid)
    local hours = math.floor(gametime / 60)
    local minutes = gametime - (hours * 60)

    local daysalive = PEARL.DB:GetField(userid, "daysalive")
    local totaldays = PEARL.DB:GetField(userid, "totaldays")
    local deathscount = PEARL.DB:GetField(userid, "deathscount")

    local repvalue = PEARL.Reputation:GetOf(userid)
    local repstring = MARKDOWN.codeline(repvalue)
    local gains = math.floor(PEARL.Reputation:GetTodayGainsOf(userid))
    local postfix = " "
    if gains > 0 then
        postfix = " "..PEARL.ICONS.ARROW_UP.." +"..tostring(gains)
    elseif gains < 0 then
        postfix = " "..PEARL.ICONS.ARROW_DOWN.." "..tostring(gains)
    elseif repvalue < PEARL.Reputation.STARTING_VALUE then
        postfix = " "..PEARL.ICONS.WARN
    end
    repstring = repstring..postfix

    local netprofiletimecreated = PEARL.DB:GetField(userid, "profiletimecreated")
    local gameplayed = P_STRINGS.UNKNOWN
    if hours > 0 and minutes > 0 then
        gameplayed = MARKDOWN.codeline(STRINGS.PEARL.HM_TIME_FORMAT:format(
            hours, minutes
        ))
    end

    local embed = Embed()
        :SetTitle(P_STRINGS.TITLE:format(icon, dbr.username or "UNKNOWN"))
        :SetColor(Embed.COLORS.BLUE)
        :SetThumbnail(dbr.avatar)
        :SetFooter(P_STRINGS.FOOTER:format(userid, dbr.netid or "???"), P_STRINGS.FOOTER_ICON)
        :AddField(P_STRINGS.FD_NAMES.PLAYED, MARKDOWN.codeline(STRINGS.PEARL.PROPORTION:format(
            daysalive, totaldays
        )), true)
        :AddField(P_STRINGS.FD_NAMES.DEATHS, MARKDOWN.codeline(deathscount), true)
        :AddField(P_STRINGS.FD_NAMES.REP, repstring, true)
        :AddField(P_STRINGS.FD_NAMES.SEEN, last_seen_time, true)
        :AddField(P_STRINGS.FD_NAMES.LOCALE, loc_icon and loc_icon.." "..loc_str or P_STRINGS.UNKNOWN, true)
        :AddField(P_STRINGS.FD_NAMES.GAMEPLAYTIME, gameplayed, true)
        :SetFooter(P_STRINGS.FOOTER:format(userid, dbr.netid or "???"), P_STRINGS.FOOTER_ICON)

    if dbr.netid then
        embed:SetUrl(PEARL.CONSTS.STEAM_ACCOUNT_URL:format(dbr.netid))
    end

    if dbr[PEARL.AccountBindings.BINDING_FIELD[PEARL.AccountBindings.BINDING_TYPE.DISCORD]] then
        embed:AddField(P_STRINGS.FD_NAMES.DISCORD, MARKDOWN.mention(dbr.discordid, MARKDOWN.MENTION_TYPE.USER), true)
    end

    if netprofiletimecreated then
        embed:AddField(P_STRINGS.FD_NAMES.STEAMCREATED, MARKDOWN.timestamp(netprofiletimecreated), true)
    end

    if dbr.rootuserid and dbr.rootuserid ~= userid then
        embed:AddField(P_STRINGS.FD_NAMES.ALT_ACCOUNT, PEARL.DB:MentionOrName(dbr.rootuserid))
    end

    if dbr.bans and table.empty(dbr.bans) == false then
        local lastban = dbr.bans[#dbr.bans]
        local active = lastban.timestop == nil
        local author = lastban.author
        if author == PEARL.CONSTS.BAN_AUTHORS.SYSTEM then
            author = MARKDOWN.italic(P_STRINGS.SYSTEM_BAN)
        else
            author = author and PEARL.DB:MentionOrName(author) or MARKDOWN.italic(P_STRINGS.UNKNOWN_AUTHOR)
        end

        embed:AddField(P_STRINGS.FD_NAMES.LAST_BAN, P_STRINGS.FD_VALUES.LAST_BAN:format(
            author,
            MARKDOWN.timestamp(lastban.timestart)..(
                active and " "..P_STRINGS.ACTIVE_BAN_TAG or " "..P_STRINGS.BAN_END:format(
                    MARKDOWN.timestamp(lastban.timestop)
                )
            ),
            lastban.reason or MARKDOWN.italic(P_STRINGS.NO_REASON)
        ), false) -- Print all these on a new line always.
    end

    local description = ""

    -- Check for explicity true since this is false by default.
    if dbr.communityprofile == false then
        description = PEARL.ICONS.WARN.." "..MARKDOWN.italic(P_STRINGS.NOT_SETUPED)
    elseif dbr.privateprofile == true then
        description = PEARL.ICONS.INFO.." "..MARKDOWN.italic(P_STRINGS.PRIVATE)
    end

    if dbr.modnote and all == true then
        description = description.."\n\n"..P_STRINGS.MOD_NOTE:format(dbr.modnote)
    end

    embed:SetDescription(description)

    return embed
end

-------------------------------------
-- [[ Return ]]
-------------------------------------

return EMBEDS
