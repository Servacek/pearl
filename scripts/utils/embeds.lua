--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local Embed = PEARL.loadfile("libraries/discordapi/models/embed")

local MARKDOWN = PEARL.loadfile("libraries/markdown")
local TEMPLATES = require("widgets/redux/templates")


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
    local name      = pmd:GetName() or ""
    local inventory = pmd:GetInventory()
    local prefab    = pmd:GetPrefab()
    local age       = pmd:GetAgeInDays()

    local client    = userid and (PEARL.ServerNetwork:GetCachedClientTableFor(userid) or TheNet:GetClientTableForUser(userid))
    local url       = client and client.netid and PEARL.CONSTS.STEAM_ACCOUNT_URL:format(client.netid)

    local description = ""
    local max_prefab_size = PEARL.GetMaxStringSize(inventory, true)
    local max_count_size = PEARL.GetMaxStringSize(inventory)

    for iprefab, icount in pairs(inventory) do
        icount = tostring(icount)
        local line = MARKDOWN.codeline(string.rep(" ", max_count_size - #icount)..icount.."x").." "..
        MARKDOWN.codeline(iprefab..string.rep(" ", max_prefab_size - #iprefab)).." "..PEARL.PrefabToName(iprefab)

        -- Keep the highlighted items on top.
        if type(highlighted) == "table" and (table.contains(highlighted, iprefab) or highlighted[iprefab] == 1) then
            description = MARKDOWN.bold(line).."\n"..description
        else
            description = description..line.."\n"
        end
    end

    if #description <= 0 then
        description = STRINGS.PEARL.LOGS.INV_EMBED_IVNENTORY_TITLE_EMPTY
    else
        description = STRINGS.PEARL.LOGS.INV_EMBED_INVENTORY_TITLE.."\n"..description
    end

    local icon = PEARL.ICONS.PLAYER_PREFABS[prefab] or PEARL.ICONS.PLAYER_PREFABS[""]

    --- @type Embed
    local embed = Embed()
    embed:SetTitle(STRINGS.PEARL.LOGS.INV_EMBED_TITLE:format(
        icon, name, userid
    ), url)
    embed:SetDescription(description)
    embed:SetTimestamp(os.time())

    embed:AddField(STRINGS.PEARL.LOGS.INV_EMBED_FIELD_NAMES.SURVIVED, STRINGS.PEARL.LOGS.INV_EMBED_SURVIVED_VALUE:format(
        age and age or "?", TheWorld and TheWorld.state.cycles + 1 or "?"
    ))

    if client ~= nil and client.color then
        embed:SetColor(PEARL.RGBToDecimal(PEARL.PercentToRGB(client.color)))
    end

    return embed
end

function EMBEDS.SuspiciousInventory(pwd, suspiciousness)
    -- Highlight rare items
    local embed = EMBEDS.Inventory(pwd, PEARL.PREFABS.RARE_ITEMS)
    if type(suspiciousness) == "number" then
        embed:AddField(
            STRINGS.PEARL.LOGS.INV_EMBED_FIELD_NAMES.SUSPICIOUSNESS,
            MARKDOWN.codeline(tostring(math.floor(suspiciousness * 100)).."%")
        )
    end

    return embed
end

--- @return Embed
function EMBEDS.ServerBoot()
    return Embed()
        :SetTitle(STRINGS.PEARL.LOGS.STARTUP_EMBED_TITLE)
        :SetColor(Embed.COLORS.GREEN)
        :SetThumbnail(STRINGS.PEARL.LOGS.STARTUP_EMBED_THUMBNAIL_URL)
        :SetTimestamp(os.time())

        :AddField(STRINGS.PEARL.LOGS.STARTUP_EMBED_FIELD_NAMES.PLATFORM, MARKDOWN.codeline(PLATFORM), true)
        :AddField(STRINGS.PEARL.LOGS.STARTUP_EMBED_FIELD_NAMES.MOD_V, MARKDOWN.codeline(PEARL.MOD_INFO.version), true)
        :AddField(STRINGS.PEARL.LOGS.STARTUP_EMBED_FIELD_NAMES.GAME_V, MARKDOWN.codeline(TEMPLATES.GetBuildString()), true)
        :AddField(STRINGS.PEARL.LOGS.STARTUP_EMBED_FIELD_NAMES.SEED, MARKDOWN.codeline(TheWorld.meta.seed), true)
        :AddField(STRINGS.PEARL.LOGS.STARTUP_EMBED_FIELD_NAMES.PLAYSTYLE, MARKDOWN.codeline(TheNet:GetServerGameMode()), true)
end

--- @TODO: Create embed for mod list.
--- @return Embed
function EMBEDS.ClientMods(enabled_mods, owner_name)
    local description = ""

    local index = 1
    for _, mod in pairs(enabled_mods) do
        local icon = mod.blocked and PEARL.ICONS.X or PEARL.ICONS.CHECK
        local fancyname = MARKDOWN.bold(mod.fancyname)

        description = description..MARKDOWN.codeline(tostring(index)..". ")..icon.." "
        if not mod.private or mod.temp then
            description = description..MARKDOWN.hlink(
                fancyname, PEARL.CONSTS.STEAM_WORKSHOP:format(mod.id)
            )
        else
            description = description..fancyname.."[LOCAL MOD]"
        end

        if mod.temp == true then
            description = description.."[TEMP]"
        end

        description = description.."\n"
        index = index + 1
    end

    return Embed()
        :SetTitle(STRINGS.PEARL.LOGS.MODS_EMBED_TITLE:format(owner_name))
        :SetColor(Embed.COLORS.RED)
        :SetTimestamp(os.time())
        :SetDescription(description)
end


-------------------------------------
-- [[ Return ]]
-------------------------------------

return EMBEDS
