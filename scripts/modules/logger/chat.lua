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
    -- Ignore emote commands
    if not (userid and cmd and guid) then
        return
    end

    local command = UserCommands.GetCommandFromName(cmd)
    if not command or command.emote then
        return
    end

    PEARL.DiscordLogger:LogStringRaw(
        STRINGS.PEARL.LOGS.SAY_COMMAND:format(tostring(UserToName(userid) or userid), cmd),
        PEARL.ICONS.PLAYER_STATE.CMD_SEND
    )
end)

PEARL.AddGlobalFunctionPreCall("Networking_Announcement", function(message, colour, announce_type)
    -- Announcements are broadcasted between all shards
    if not (message and TheShard:IsMaster()) then
        return
    end

    PEARL.DiscordLogger:LogString(
        message, PEARL.ICONS.ANNOUNCEMENTS[announce_type]
            or PEARL.ICONS.ANNOUNCEMENTS['default']
            or MARKDOWN.codeline(STRINGS.PEARL.LOGS.TAG:format(
                STRINGS.PEARL.LOGS.ANNOUNCEMENT
            )
        )
    )
end)
-- Debug with d_test_skins_announce([skin_name])
PEARL.AddGlobalFunctionPreCall("Networking_SkinAnnouncement", function (user_name, user_colour, skin_name)
    -- Skin received events are broadcasted between all shards
    if not (user_name and skin_name and TheShard:IsMaster()) then
        return
    end

    PEARL.DiscordLogger:LogEmbed(Embed()
        :SetDescription(MARKDOWN.escape(GetSkinDescription(skin_name)))
        :SetColor(PEARL.RGBToDecimal(PEARL.PercentToRGB(
            GetColorForItem(skin_name)
        )))
        :SetThumbnail(PEARL.CONSTS.SKINS_PREVIEW_URL:format(
            -- Looks like the database uses upper case for naming...
            string.upper(skin_name), "small"
        ))
        :SetTitle(
            PEARL.ICONS.ANNOUNCEMENTS["skin"].." "..STRINGS.PEARL.LOGS.SKIN_RECEIVED
            :format(
                user_name, GetSkinName(skin_name)
            )
        )

        -- The image is too big
        -- :SetImage(PEARL.CONSTS.SKINS_PREVIEW_URL:format(
        --     skin_name, "small"
        -- ))
    )
end)

--- @TODO: Handle unicode characters properly here since JSON doesn't accept it.
--- Normalize it before sending to discord.
PEARL.AddGlobalFunctionPreCall("Networking_Say", function (guid, userid, name, prefab, message, colour, whisper)
    if not (message and name and userid and prefab) then
        return
    end

    -- Whispers aren't broadcasted to other shards
    if not whisper and TheShard:IsSecondary() then
        return
    end

    if ProfanityFilter and PEARL.CONFIG.PROFANITY_FILTERS.enabled then
        message = ProfanityFilter:Apply(message)
    end

    local icon = PEARL.ICONS.PLAYER_PREFABS[prefab] or MARKDOWN.codeline("["..string.capitalize(prefab).."]")
    message = (whisper and STRINGS.PEARL.LOGS.SAY_WHISPER or STRINGS.PEARL.LOGS.SAY):format(
        -- This is all user input so it can contain some encoded stuff.
        -- This should be handled when we encode the message as JSON string.
        MARKDOWN.escape(name),
        MARKDOWN.escape(message):emojify()
    )

    PEARL.DiscordLogger:LogStringRaw(message, icon)
end)

PEARL.AddGlobalFunctionPreCall("Networking_SystemMessage", function(message)
    -- This is being broadcasted to all shards as well.
    if not message or TheShard:IsSecondary() then
        return
    end

    PEARL.DiscordLogger:LogStringRaw(STRINGS.PEARL.LOGS.SAY:format(
        "[Server]", message
    ), PEARL.ICONS.PLAYER_PREFABS["server"])
end)
