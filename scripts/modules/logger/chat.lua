--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]



local TheShard = TheShard
local PEARL = PEARL
local string = string
local GetSkinDescription, GetSkinName, GetColorForItem, UserToName = GetSkinDescription, GetSkinName, GetColorForItem, UserToName

local MARKDOWN = PEARL.loadfile("libraries/markdown")
local Embed = PEARL.loadfile("libraries/discordapi/models/embed")

local UserCommands = require("usercommands")

-----------------------------
-- [[ Networking Handlers ]]
-----------------------------

PEARL.AddGlobalFunctionPreCall("Networking_SlashCmd", function(guid, userid, cmd)
    if not (userid and cmd and guid) then
        return
    end

    -- Skip emote commands
    local command = UserCommands.GetCommandFromName(cmd)
    if not command or command.emote then
        return
    end

    PEARL.DiscordLogger:LogStringRaw(
        STRINGS.PEARL.LOGS.SAY_COMMAND:format(
            MARKDOWN.escape(UserToName(userid) or userid), cmd
        ),
        PEARL.ICONS.PLAYER_STATE.CMD_SEND
    )
end)

PEARL.AddGlobalFunctionPreCall("Networking_Announcement", function(message, colour, announce_type)
    -- Announcements are broadcasted between all shards
    if not (message and TheShard:IsMaster()) then
        return
    end

    PEARL.DiscordLogger:LogString(
        message, PEARL.ICONS.ANNOUNCEMENTS[string.lower(announce_type)]
            or PEARL.ICONS.ANNOUNCEMENTS['default']
            or MARKDOWN.codeline(STRINGS.PEARL.LOGS.TAG:format(
                STRINGS.PEARL.LOGS.ANNOUNCEMENT
            )
        )
    )
end)

-- Debug with d_test_skins_announce([skin_name])
PEARL.AddGlobalFunctionPreCall("Networking_SkinAnnouncement", function (user_name, user_colour, skin_prefab)
    -- Skin received events are broadcasted between all shards
    if not (user_name and skin_prefab and TheShard:IsMaster()) then
        return
    end

    PEARL.DiscordLogger:LogEmbed(Embed()
        :SetDescription(MARKDOWN.escape(GetSkinDescription(skin_prefab)))
        :SetColor(PEARL.RGBToDecimal(PEARL.PercentToRGB(
            GetColorForItem(skin_prefab)
        )))
        :SetThumbnail(PEARL.CONSTS.SKINS_PREVIEW_URL:format(
            -- Looks like the database uses upper case for naming...
            string.upper(skin_prefab), "small"
        ))
        :SetTitle(
            PEARL.ICONS.ANNOUNCEMENTS["skin"].." "..STRINGS.PEARL.LOGS.SKIN_RECEIVED
            :format(
                MARKDOWN.escape(user_name), MARKDOWN.escape(GetSkinName(skin_prefab))
            )
        )

        -- The image is too big
        -- :SetImage(PEARL.CONSTS.SKINS_PREVIEW_URL:format(
        --     skin_name, "small"
        -- ))
    )
end)

PEARL.AddGlobalFunctionPreCall("Networking_Say", function (guid, userid, name, prefab, message, colour, whisper, isemote, vanity)
    if not (message and name) then
        return
    end

    -- Whispers aren't broadcasted to other shards
    -- Everything else is, so handly whispers per shard.
    if not whisper and TheShard:IsSecondary() then
        return
    end

    -- Escape here so even profanity filter is safe when using spoilers
    message = MARKDOWN.escape(message)
    if ProfanityFilter and PEARL.CONFIG.PROFANITY_FILTERS.enabled then
        message = ProfanityFilter:Apply(message, MARKDOWN.PATTERNS.SPOILER, true)
    end

    local player = Ents[guid]
    if player then
        prefab = player:GetFancyPrefabName()
    end

    local icon = type(vanity) == "table" and PEARL.ICONS.PLAYER_VANITY[vanity[2]]
    if not icon and type(prefab) == "string" then
        icon = PEARL.ICONS.PLAYER_PREFABS[prefab] or MARKDOWN.codeline("["..prefab:capitalize().."]")
    end

    message = (whisper and STRINGS.PEARL.LOGS.SAY_WHISPER or STRINGS.PEARL.LOGS.SAY):format(
        -- This is all user input so it can contain some encoded stuff.
        -- This should be handled when we encode the message as JSON string.
        MARKDOWN.escape(name),
        message:emojify()
    )

    PEARL.DiscordLogger:LogStringRaw(message, icon or PEARL.ICONS.PLAYER_PREFABS.unknown)
end)

PEARL.AddGlobalFunctionPreCall("Networking_SystemMessage", function(message)
    -- This is being broadcasted to all shards as well.
    if not message or TheShard:IsSecondary() then
        return
    end

    PEARL.DiscordLogger:LogStringRaw(STRINGS.PEARL.LOGS.SAY:format(
        "[Server]", MARKDOWN.escape(message):emojify()
    ), PEARL.ICONS.PLAYER_PREFABS["server"])
end)
