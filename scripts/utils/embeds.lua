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
    local name      = pmd:GetName() or ""
    local inventory = pmd:GetInventory()
    local prefab    = pmd:GetPrefab()
    local age       = pmd:GetAge()
    local netid     = pmd:GetNetID()
    local url       = netid and PEARL.CONSTS.STEAM_ACCOUNT_URL:format(netid)


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
            MARKDOWN.codeline(tostring(math.floor(suspiciousness * 100)).."%")
        )
    end

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
        :AddField(STRINGS.PEARL.EMBEDS.STARTUP.FD_NAMES.EVENT, STRINGS.UI.SPECIAL_EVENT_NAMES[string.upper(active_event)] or STRINGS.PEARL.LOGS.NONE_EVENT)
end

--- @return Embed
function EMBEDS.WorldRegen(world, session_id)
    world = world or TheWorld
    session_id = session_id or TheNet:GetSessionIdentifier() or "???"
    local seed = world and world.meta and world.meta.seed or "???"
    local save_version = world and world.meta and world.meta.generated_on_saveversion or "???"

    return Embed()
        :SetTitle(STRINGS.PEARL.EMBEDS.REGEN.TITLE:format(PEARL.GetShardFancyName()))
        :SetColor(Embed.COLORS.GREEN)
        :SetThumbnail(STRINGS.PEARL.EMBEDS.REGEN.THMB_URL)
        :SetTimestamp(os.time())

        :AddField(STRINGS.PEARL.EMBEDS.REGEN.FD_NAMES.SEED, MARKDOWN.codeline(seed), true)
        :AddField(STRINGS.PEARL.EMBEDS.REGEN.FD_NAMES.SESSION_ID, MARKDOWN.codeline(session_id), true)
        :AddField(STRINGS.PEARL.EMBEDS.REGEN.FD_NAMES.SAVE_VERSION, MARKDOWN.codeline(save_version), true)
end

--- @return Embed
function EMBEDS.ClientMods(enabled_mods, owner_name)
    local description = ""
    local max_id_size = PEARL.GetMaxStringSize(enabled_mods, false, "id")

    -- Data processed here are untrusted.
    for _, mod in ipairs(enabled_mods) do
        local type_icon = mod.private and PEARL.ICONS.LOCAL or PEARL.ICONS.STEAM
        local state_icon = mod.allowed and PEARL.ICONS.CHECK or PEARL.ICONS.X
        local fancyname = MARKDOWN.bold(type(mod.fancyname) == "string" and mod.fancyname:ltake(MAX_MODNAME_LEN, "...") or "???")

        local modid = ""
        if not mod.private then
            modid = type(mod.id) == "string" and mod.id:ltake(MAX_MODID_LEN) or "???"
            local modid_spac = string.rep(" ", max_id_size - #mod.id)
            modid = MARKDOWN.codeline(modid..modid_spac)
            modid = (MARKDOWN.hlink(
                modid, PEARL.CONSTS.STEAM_WORKSHOP:format(tostring(mod.id):ltake(MAX_MODID_LEN, "..."))
            ).." ")
        else
            modid = MARKDOWN.codeline(string.rep(" ", max_id_size)).." "
        end

        description = description..type_icon.." "..state_icon.." "..modid..(
            mod.allowed and fancyname or MARKDOWN.strikethrough(fancyname)
        )

        description = description.."\n"
    end

    return Embed()
        :SetTitle(STRINGS.PEARL.EMBEDS.MODS.TITLE:format(MARKDOWN.codeline(owner_name)))
        :SetColor(Embed.COLORS.RED)
        :SetTimestamp(os.time())
        :SetDescription(description)
        :SetFooter(string.format("%s/%s", #enabled_mods, tostring(enabled_mods.count)))
end


-------------------------------------
-- [[ Return ]]
-------------------------------------

return EMBEDS
