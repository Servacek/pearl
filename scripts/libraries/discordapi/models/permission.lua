--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 223 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


------------------------------------------
-- [[ Class Declaration ]]
------------------------------------------

--- @enum Permission
local Permission = {
    CREATE_INSTANT_INVITE               = bit.lshift(1, 0),	    -- Allows creation of instant invites
    KICK_MEMBERS                        = bit.lshift(1, 1),	    -- Allows kicking members
    BAN_MEMBERS                         = bit.lshift(1, 2),	    -- Allows banning members
    ADMINISTRATOR                       = bit.lshift(1, 3),	    -- Allows all permissions and bypasses channel permission overwrites
    MANAGE_CHANNELS                     = bit.lshift(1, 4),	    -- Allows management and editing of channels
    MANAGE_GUILD                        = bit.lshift(1, 5),	    -- Allows management and editing of the guild
    ADD_REACTIONS                       = bit.lshift(1, 6),	    -- Allows for the addition of reactions to messages
    VIEW_AUDIT_LOG                      = bit.lshift(1, 7),	    -- Allows for viewing of audit logs
    PRIORITY_SPEAKER                    = bit.lshift(1, 8),	    -- Allows for using priority speaker in a voice channel
    STREAM                              = bit.lshift(1, 9),	    -- Allows the user to go live
    VIEW_CHANNEL                        = bit.lshift(1, 10),	-- Allows guild members to view a channel, which includes reading messages in text channels and joining voice channels
    SEND_MESSAGES                       = bit.lshift(1, 11),	-- Allows for sending messages in a channel and creating threads in a forum does not allow sending messages in threads
    SEND_TTS_MESSAGES                   = bit.lshift(1, 12),	-- Allows for sending of /tts messages
    MANAGE_MESSAGES                     = bit.lshift(1, 13),	-- Allows for deletion of other users messages
    EMBED_LINKS                         = bit.lshift(1, 14),	-- Links sent by users with this permission will be auto-embedded
    ATTACH_FILES                        = bit.lshift(1, 15),	-- Allows for uploading images and files
    READ_MESSAGE_HISTORY                = bit.lshift(1, 16),	-- Allows for reading of message history
    MENTION_EVERYONE                    = bit.lshift(1, 17),	-- Allows for using the @everyone tag to notify all users in a channel, and the @here tag to notify all online users in a channel
    USE_EXTERNAL_EMOJIS                 = bit.lshift(1, 18),	-- Allows the usage of custom emojis from other servers
    VIEW_GUILD_INSIGHTS                 = bit.lshift(1, 19),	-- Allows for viewing guild insights
    CONNECT                             = bit.lshift(1, 20),	-- Allows for joining of a voice channel
    SPEAK                               = bit.lshift(1, 21),	-- Allows for speaking in a voice channel
    MUTE_MEMBERS                        = bit.lshift(1, 22),	-- Allows for muting members in a voice channel
    DEAFEN_MEMBERS                      = bit.lshift(1, 23),	-- Allows for deafening of members in a voice channel
    MOVE_MEMBERS                        = bit.lshift(1, 24),	-- Allows for moving of members between voice channels
    USE_VAD                             = bit.lshift(1, 25),	-- Allows for using voice-activity-detection in a voice channel
    CHANGE_NICKNAME                     = bit.lshift(1, 26),	-- Allows for modification of own nickname
    MANAGE_NICKNAMES                    = bit.lshift(1, 27),	-- Allows for modification of other users nicknames
    MANAGE_ROLES                        = bit.lshift(1, 28),	-- Allows management and editing of roles
    MANAGE_WEBHOOKS                     = bit.lshift(1, 29),	-- Allows management and editing of webhooks
    MANAGE_GUILD_EXPRESSIONS            = bit.lshift(1, 30),	-- Allows for editing and deleting emojis, stickers, and soundboard sounds created by all users
    USE_APPLICATION_COMMANDS            = bit.lshift(1, 31),	-- Allows members to use application commands, including slash commands and context menu commands.
    REQUEST_TO_SPEAK                    = bit.lshift(1, 32),	-- Allows for requesting to speak in stage channels. This permission is under active development and may be changed or removed.	S
    MANAGE_EVENTS                       = bit.lshift(1, 33),	-- Allows for editing and deleting scheduled events created by all users
    MANAGE_THREADS                      = bit.lshift(1, 34),    -- Allows for deleting and archiving threads, and viewing all private threads	T
    CREATE_PUBLIC_THREADS               = bit.lshift(1, 35),	-- Allows for creating public and announcement threads	T
    CREATE_PRIVATE_THREADS              = bit.lshift(1, 36),	-- Allows for creating private threads	T
    USE_EXTERNAL_STICKERS               = bit.lshift(1, 37),	-- Allows the usage of custom stickers from other servers
    SEND_MESSAGES_IN_THREADS            = bit.lshift(1, 38),	-- Allows for sending messages in threads	T
    USE_EMBEDDED_ACTIVITIES             = bit.lshift(1, 39),	-- Allows for using Activities applications with the EMBEDDED flag in a voice channel	V
    MODERATE_MEMBERS                    = bit.lshift(1, 40),	-- Allows for timing out users to prevent them from sending or reacting to messages in chat and threads, and from speaking in voice and stage channels
    VIEW_CREATOR_MONETIZATION_ANALYTICS = bit.lshift(1, 41),	-- Allows for viewing role subscription insights
    USE_SOUNDBOARD                      = bit.lshift(1, 42),	-- Allows for using soundboard in a voice channel	V
    CREATE_GUILD_EXPRESSIONS            = bit.lshift(1, 43),	-- Allows for creating emojis, stickers, and soundboard sounds, and editing and deleting those created by the current user. Not yet available to developers, see changelog.
    CREATE_EVENTS                       = bit.lshift(1, 44),	-- Allows for creating scheduled events, and editing and deleting those created by the current user. Not yet available to developers, see changelog.
    USE_EXTERNAL_SOUNDS                 = bit.lshift(1, 45),	-- Allows the usage of custom soundboard sounds from other servers	V
    SEND_VOICE_MESSAGES                 = bit.lshift(1, 46),	-- Allows sending voice messages
}

------------------------------------------
-- [[ Return ]]
------------------------------------------

return Permission
