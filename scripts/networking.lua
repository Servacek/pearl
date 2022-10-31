local G = GLOBAL
local SUB = G.SUB

local _Networking_SlashCmd = G.Networking_SlashCmd
G.Networking_SlashCmd = function(guid, userid, cmd, ...)
    SUB.Logger:OnSlashCommand(userid, cmd)

    return _Networking_SlashCmd(guid, userid, cmd, ...)
end

local _Networking_Announcement = G.Networking_Announcement
G.Networking_Announcement = function(message, colour, announce_type, ...)
    SUB.Logger:OnAnnouncement(message, announce_type)

    return _Networking_Announcement(message, colour, announce_type, ...)
end

local _Networking_SkinAnnouncement = G.Networking_SkinAnnouncement
G.Networking_SkinAnnouncement = function(user_name, user_colour, skin_name, ...)
    SUB.Logger:OnSkinReceived(user_name, skin_name)

    return _Networking_SkinAnnouncement(user_name, user_colour, skin_name, ...)
end

local _Networking_Say = G.Networking_Say
G.Networking_Say = function(guid, userid, name, prefab, message, colour, whisper, isemote, user_vanity, ...)
    SUB.Logger:OnSay(userid, name, prefab, message, whisper)

    return _Networking_Say(guid, userid, name, prefab, message, colour, whisper, isemote, user_vanity, ...)
end