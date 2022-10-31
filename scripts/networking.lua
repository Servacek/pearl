setfenv(1, _G.SUB.env)
local SUB = SUB
local TheNet = TheNet

-- Note: These needs to be accessed via _G
-- since they are not defined in our enviroment
-----------------------------
-- [[ Networking Handlers ]]
-----------------------------

local _Networking_SlashCmd = _G.Networking_SlashCmd
_G.Networking_SlashCmd = function(guid, userid, cmd, ...)
    SUB.SafeRun(SUB.Logger.OnSlashCommand, userid, cmd)

    local client = TheNet:GetClientTableForUser(userid)
    if not (client and client.admin) and not SUB.IsCommandAllowed(cmd) then
        return
    end

    return _Networking_SlashCmd(guid, userid, cmd, ...)
end

local _Networking_Announcement = _G.Networking_Announcement
_G.Networking_Announcement = function(message, colour, announce_type, ...)
    SUB.SafeRun(SUB.Logger.OnAnnouncement, message, announce_type)

    return _Networking_Announcement(message, colour, announce_type, ...)
end

local _Networking_SkinAnnouncement = _G.Networking_SkinAnnouncement
_G.Networking_SkinAnnouncement = function(user_name, user_colour, skin_name, ...)
    SUB.SafeRun(SUB.Logger.OnSkinReceived, user_name, skin_name)

    return _Networking_SkinAnnouncement(user_name, user_colour, skin_name, ...)
end

local _Networking_Say = _G.Networking_Say
_G.Networking_Say = function(guid, userid, name, prefab, message, colour, whisper, isemote, user_vanity, ...)
    SUB.SafeRun(SUB.Logger.OnSay, userid, name, prefab, message, whisper)

    return _Networking_Say(guid, userid, name, prefab, message, colour, whisper, isemote, user_vanity, ...)
end
