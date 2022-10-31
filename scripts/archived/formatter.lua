local Message = require('components/message')
local ICONS = require('constants/icons')
local SKINS_PREVIEW_URL = "items.kleientertainment.com/images/DST/%s/%s"
local FORMAT_CHARS = {
    "*",
    "_",
    ">",
    "|",
    "~",
    "`",
    ":",
}

local formatter = {}

------------------------------------------------
-- Local String Helpers
------------------------------------------------

-- Disable Discord Formatting
function string.DDF(str)
    for _, char in ipairs(FORMAT_CHARS) do
        str = str:gsub("%"..char, "%\\"..char)
    end

    return str
end

-- Make the first letter upper case
function string.capitalize(str)
    return (str:gsub("^%l", string.upper))
end

-- Replaces all known dst emoticons in a string with discord emojis
function string.emojify(str)
    for utf8_str, emoji in pairs(ICONS.DISCORD_EMOTES) do
        str = str:gsub("%"..utf8_str, "%"..emoji)
    end

    return str
end

-- Removes all known dst emoticons from a string
function string.deemojify(str)
    for utf8_str, emoji in pairs(ICONS.DISCORD_EMOTES) do
        str = str:gsub("%"..utf8_str, "")
    end

    return str
end

function string.codeblock(str)
    return "`"..str.."`"
end

-- Deprecated
local function GetAnnouncementIcon(str)
    for utf8_str, emoji in pairs(ICONS.DISCORD_EMOTES) do
        if string.find(str, utf8_str) then
            return emoji
        end
    end
end

-- default size = "small"
local function GetSkinPreviewURL(skin_prefab, size)
    return string.format(SKINS_PREVIEW_URL, skin_prefab, size or "small")
end

local function GetSkinName(skin_prefab)
    return STRINGS.SKIN_NAMES[skin_prefab]
end

local function GetClient(userid)
    for _, client in ipairs(GetPlayerClientTable()) do
        if client.userid == userid then
            return client
        end
    end

    return {}
end

local function GetShardName()
    if TheShard:IsMaster() then
        return "Caves"
    end

    return "Overworld"
end

local function CreateEmbed(title, description, image_url)
    return {
        title = title,
        description = description,
        image = {
            url = image_url,
        },
    }
end

------------------------------------------------------------------------

function formatter.FormatAnnouncement(str, announce_type)
    if str ~= nil then
        local header = ICONS.LOGS[announce_type] or GetAnnouncementIcon(str) or string.codeblock("[Announcement]")

        return Message(header.." "..string.codeblock(string.deemojify(string.DDF(str))))
    end
end

-- TODO?
function formatter.FormatDeathAnnouncement(str, announce_type)

end

-- TODO
function formatter.FormatSkinAnnouncement(user_name, skin_prefab)
    if user_name ~= nil and skin_prefab ~= nil then
        return Message(nil, {
                CreateEmbed(string.DDF(user_name).." has received "..GetSkinName(skin_prefab).."!", nil, GetSkinPreviewURL(skin_prefab)),
            }
        )
    end
end

function formatter.FormatMessage(str, name, userid, prefab)
    if str ~= nil and name ~= nil and userid ~= nil and prefab ~= nil then
        local header = ICONS.PLAYER_PREFABS[prefab] or string.codeblock("["..string.capitalize(prefab).."]")

        return Message(header.." ("..string.codeblock("..userid..")..") **"..string.DDF(name).."**: "..string.emojify(string.DDF(str)))
    end
end

function formatter.FormatWhisper(str, name, userid, prefab)
    if str ~= nil and name ~= nil and userid ~= nil and prefab ~= nil then
        local header = ICONS.PLAYER_PREFABS[prefab] or string.codeblock("["..string.capitalize(prefab).."]")

        return Message(header.." ("..string.codeblock("..userid..")..") **[W] "..string.DDF(name).."**: *"..string.emojify(string.DDF(str)).."*")
    end
end

function formatter.FormatAuthentication(userid)
    local name = GetClient(userid).name

    if name ~= nil and userid ~= nil then
        local header = ICONS.LOGS["auth"] or string.codeblock("[Authentication]")

        return Message(header.." "..string.codeblock(userid.." authenticated as "..name))
    end
end

function formatter.FormatDisconnection(userid)
    if userid ~= nil then
        return Message(string.codeblock(userid.." disconnected from shard "..GetShardName()))
    end
end

-----------------------------------------------------------------------

function formatter.FormatCyclesChanged(cycle)
    local season = TheWorld.state.season
    if cycle ~= nil and season ~= nil then
        return Message(
            string.codeblock(string.rep(" ", 40).."Day "..(cycle + 1).." - "..string.capitalize(season)..""..string.rep(" ", 40))
        )
    end
end

function formatter.FormatPhaseChanged(phase)
    if phase ~= nil then
        return Message(string.codeblock(string.capitalize(phase)))
    end
end

---------------------------------------------------------------------

function formatter.FormatShutdown()
    return Message(string.codeblock("[Shard] Saving and shutting down..."))
end

function formatter.FormatRegen()
    return Message(string.codeblock("[World] Regenerating..."))
end

function formatter.FormatRollback(count)
    return Message(string.codeblock("Rolling server "..count.." snapshot(s) back..."))
end

function formatter.FormatReset()
    return Message(string.codeblock("[Shard] Restarting..."))
end

function formatter.FormatConsoleCommand(cmd, doer)
    if cmd ~= nil and #cmd > 1 and doer ~= nil then
        local header = ICONS.LOGS["cmd"] or string.codeblock("[Console]")

        return Message(header.." "..string.codeblock("Received console command input from "..doer.name.." -> "..cmd))
    end
end

return formatter