
local TheShard = TheShard
local PEARL = PEARL
local string = string
local GetSkinDescription, GetSkinName, GetColorForItem, UserToName = GetSkinDescription, GetSkinName, GetColorForItem, UserToName

local MARKDOWN = PEARL.loadfile("libraries/markdown")
local Embed = PEARL.loadfile("libraries/discordapi/models/embed")

-----------------------------
-- [[ Networking Handlers ]]
-----------------------------

PEARL.AddGlobalFunctionPreCall("Networking_SlashCmd", function(guid, userid, cmd)
    -- Ignore emote commands
    if not (userid and cmd and guid) or PEARL.IsEmoteCommand(cmd) then
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

PEARL.AddGlobalFunctionPreCall("Networking_Say", function (guid, userid, name, prefab, message, colour, whisper)
    if not (message and name and userid and prefab) then
        return
    end

    -- Whispers aren't broadcasted to other shards
    if not whisper and TheShard:IsSecondary() then
        return
    end

    if PEARL.CONFIG.PROFANITY_FILTER and ProfanityFilter then
        message = ProfanityFilter:Apply(message)
    end

    local icon = PEARL.ICONS.PLAYER_PREFABS[prefab] or MARKDOWN.codeline("["..string.capitalize(prefab).."]")
    message = (whisper and STRINGS.PEARL.LOGS.SAY_WHISPER or STRINGS.PEARL.LOGS.SAY):format(
        MARKDOWN.escape(name),
        MARKDOWN.escape(message:emojify())
    )

    PEARL.DiscordLogger:LogStringRaw(message, icon)
end)

PEARL.AddGlobalFunctionPreCall("Networking_SystemMessage", function(message)
    if not message then
        return
    end

    PEARL.DiscordLogger:LogStringRaw(STRINGS.PEARL.LOGS.SAY:format(
        "[Server]", message
    ), PEARL.ICONS.PLAYER_PREFABS["server"])
end)
