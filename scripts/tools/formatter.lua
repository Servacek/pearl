local SKINS_PREVIEW_URL = "https://cdn-items.klei.com/dst/192x192/%s.png"
local ICONS = SUB.ICONS
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

local function GetAnnouncementIcon(str)
    for utf8_str, emoji in pairs(ICONS.DISCORD_EMOTES) do
        if string.find(str, utf8_str) then
            return emoji
        end
    end
end

local function GetSkinPreviewURL(skin_prefab)
    return string.format(SKINS_PREVIEW_URL, skin_prefab)
end

------------------------------------------------------------------------

function formatter.FormatAnnouncement(str, announce_type)
    if str ~= nil then
        local header = ICONS.LOGS[announce_type] or GetAnnouncementIcon(str) or "`[Announcement]`"

        return header.." `"..string.deemojify(string.DDF(str)).."`"
    end
end

function formatter.FormatSkinAnnouncement(user_name, skin_prefab)
    if user_name ~= nil and skin_prefab ~= nil then
        return "**"..string.DDF(user_name).." has received a new skin!**\n"..GetSkinPreviewURL(skin_prefab)
    end
end

function formatter.FormatMessage(str, name, userid, prefab)
    if str ~= nil and name ~= nil and userid ~= nil and prefab ~= nil then
        local header = ICONS.PLAYER_PREFABS[prefab] or ("`["..string.capitalize(prefab).."]`")

        return header.." (`"..userid.."`) **"..string.DDF(name).."**: "..string.emojify(string.DDF(str))
    end
end

function formatter.FormatWhisper(str, name, userid, prefab)
    if str ~= nil and name ~= nil and userid ~= nil and prefab ~= nil then
        local header = ICONS.PLAYER_PREFABS[prefab] or ("`["..string.capitalize(prefab).."]`")

        return header.." (`"..userid.."`) **[W] "..string.DDF(name).."**: *"..string.emojify(string.DDF(str)).."*"
    end
end

function formatter.FormatAuthentication(name, userid)
    if name ~= nil and userid ~= nil then
        local header = ICONS.LOGS["auth"] or "`[Authentication]`"

        return header.." `"..userid.." authenticated as "..name.."`"
    end
end

-----------------------------------------------------------------------

function formatter.FormatCyclesChanged(cycle)
    local season = TheWorld.state.season
    if cycle ~= nil and season ~= nil then
        return "`"..string.rep(" ", 40).."Day "..(cycle + 1).." - "..string.capitalize(season)..""..string.rep(" ", 40).."`"
    end
end

function formatter.FormatPhaseChanged(phase)
    if phase ~= nil then
        return "`"..string.capitalize(phase).."`"
    end
end

---------------------------------------------------------------------

function formatter.FormatConsoleCommand(cmd, doer)
    if cmd ~= nil and #cmd > 1 and doer ~= nil then
        local header = ICONS.LOGS["cmd"] or "`[Console]`"

        return header.." `Received console command input from "..doer.name.." -> "..cmd.."`"
    end
end

return formatter