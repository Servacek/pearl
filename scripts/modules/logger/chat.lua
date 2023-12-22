--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
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

local Colour = PEARL.loadfile("libraries/colour")

local UserCommands = require("usercommands")

-----------------------------
-- [[ Networking Handlers ]]
-----------------------------

local function OnChatMessage(guid, prefab, name, content, whisper, icon, receiver, userid)
    if type(content) ~= "string" or type(name) ~= "string" then
        return
    end

    -- Whispers aren't broadcasted to other shards
    -- Everything else is, so handly whispers per shard.
    if not whisper and TheShard:IsSecondary() then
        return
    end

    -- Escape here so even profanity filter is safe when using spoilers
    content = MARKDOWN.escape(content)
    if ProfanityFilter then
        if PEARL.CONFIG.PROFANITY_FILTERS.enabled then
            local words, slurs
            content, words, slurs = ProfanityFilter:Apply(
                content, MARKDOWN.PATTERNS.SPOILER, true
            )

            if userid ~= nil and slurs and slurs > 0 then
                local mult = 1
                if words and words > 0 then
                    mult = slurs / words > .5 and 2 or mult
                end

                PEARL.Reputation:EarnFor(
                    userid, PEARL.CONSTS.REPUTATION_TABLES.OFFENSIVE_WORD_USED * slurs * mult)
            end
        elseif userid ~= nil then
            local slurs = ProfanityFilter:CountSwears(content)
            local mult = 2 -- More penalty for the words being not censored.
            PEARL.Reputation:EarnFor(
                userid, PEARL.CONSTS.REPUTATION_TABLES.OFFENSIVE_WORD_USED * slurs * mult)
        end
    end

    local player = Ents[guid]
    if player then
        prefab = player:GetFancyPrefabName()
    end

    icon = PEARL.ICONS.PLAYER_VANITY[icon]
    if not icon and type(prefab) == "string" then
        icon = PEARL.ICONS.PLAYER_PREFABS[prefab] or MARKDOWN.codeline("["..prefab:capitalize().."]")
    end

    local pattern = STRINGS.PEARL.LOGS["SAY"..((whisper == true and "_WHISPER")  or "")]
    if receiver then
        pattern = STRINGS.PEARL.LOGS.SAY_DM:iformat(2, receiver)
    end

    PEARL.DiscordLogger:LogStringRaw(pattern:format(
        -- This is all user input so it can contain some encoded stuff.
        -- This should be handled when we encode the message as JSON string.
        MARKDOWN.escape(name),
        content:emojify()
    ), icon or PEARL.ICONS.PLAYER_PREFABS.unknown)
end

local function OnAnnouncement(message, colour, announce_type)
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
end

local function OnSystemMessage(message)
    -- This is being broadcasted to all shards as well.
    if not message or TheShard:IsSecondary() then
        return
    end

    PEARL.DiscordLogger:LogStringRaw(STRINGS.PEARL.LOGS.SAY:format(
        "[Server]", MARKDOWN.escape(message):emojify()
    ), PEARL.ICONS.PLAYER_PREFABS["server"])
end

-----------------------------
-- [[ Function Pre-Calls ]]
-----------------------------

PEARL.AddGlobalFunctionPreCall("Networking_SlashCmd", function(guid, userid, cmd)
    if not (userid and type(cmd) == "string" and guid) then
        return
    end

    local name = cmd:split(" ")[1]
    -- Skip emote commands
    local command = UserCommands.GetCommandFromName(name) or UserCommands.GetCustomCommand(name)
    if not command or command.emote or command.remote == false then
        return -- @TODO: Send a report to the server that someone attempted to run an invalid command?
    end

    PEARL.DiscordLogger:LogStringRaw(
        STRINGS.PEARL.LOGS.SAY_COMMAND:format(
            MARKDOWN.escape(UserToName(userid) or userid), cmd
        ),
        PEARL.ICONS.PLAYER_STATE.CMD_SEND
    )
end)

PEARL.AddGlobalFunctionPreCall("Networking_Announcement", OnAnnouncement)

-- Debug with d_test_skins_announce([skin_name])
PEARL.AddGlobalFunctionPreCall("Networking_SkinAnnouncement", function (user_name, user_colour, skin_prefab)
    -- Skin received events are broadcasted between all shards
    if not (user_name and skin_prefab and TheShard:IsMaster()) then
        return
    end

    PEARL.DiscordLogger:LogEmbed(Embed()
        :SetDescription(MARKDOWN.escape(GetSkinDescription(skin_prefab)))
        :SetColor(Colour.PercentToDecimal(
            PEARL.unpack(GetColorForItem(skin_prefab))
        ))
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
    )
end)

PEARL.AddGlobalFunctionPreCall("Networking_Say", function (guid, userid, name, prefab, message, colour, whisper, isemote, vanity)
    OnChatMessage(guid, prefab, name, message, whisper, nil, nil, userid)
end)

PEARL.AddGlobalFunctionPreCall("Networking_SystemMessage", OnSystemMessage)

-----------------------------
-- [[ Event Listeners ]]
-----------------------------

PEARL.EventProcessor:AddEventHandler("chat_message", OnChatMessage)
PEARL.EventProcessor:AddEventHandler("chat_system_message", OnSystemMessage)
PEARL.EventProcessor:AddEventHandler("chat_announcement", OnAnnouncement)
