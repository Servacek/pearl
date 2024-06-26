--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


local MARKDOWN = require("libraries/markdown")

--------------------------------
-- [[ Constants ]]
--------------------------------

local BANLIST_FILE_PATH = PEARL.MODROOT.."/data/globalbanlist.txt"
local BANLIST_URL = PEARL.CONFIG.GLOBAL_BANLIST.URL

--------------------------------
-- [[ Locals ]]
--------------------------------

--- @type table<userid, boolean>
local banlist = {}

--------------------------------
-- [[ Local Functions ]]
--------------------------------

--- @param line string
local function AddLineToBanlist(line)
    local userid = line:match(PEARL.CONSTS.KLEI_ID_PATTERN)
    if type(userid) == "string" then
        banlist[userid:strip()] = true
    end
end

local function SaveBanlist()
    local wf = io.open(BANLIST_FILE_PATH, "w")
    if not wf then
        return PEARL.error("Failed to load the global banlist file!")
    end

    for userid, _ in pairs(banlist) do
        wf:write(userid.."\n")
    end

    wf:close()
end

--- @param str string
local function LoadBanlistFromString(str)
    PEARL.debug("LoadBanlistFromString")

    if type(str) ~= "string" then
        return
    end

    if not banlist then
        banlist = {}
    end

    cleartable(banlist)
    for _, line in ipairs(str:split("\n")) do
        AddLineToBanlist(line)
    end
end

local function LoadBanlistFromFile(filename)
    PEARL.info("Loading banned userids from local file", filename.."...")

    for line in io.lines(filename) do
        AddLineToBanlist(line)
    end

    PEARL.info("Loaded", table.size(banlist), "userid(s) from", filename)
end

local function OnBanlistFetched(str)
    LoadBanlistFromString(str)
    SaveBanlist()

    PEARL.info("Downloaded", table.size(banlist), "userid(s) from configured global banlist.")
end

local function FetchBanlistFromURL(url)
    PEARL.info("Fetching known banned userids from coonfigured global banlist...")

    return PEARL.HTTPClient:GET(url, OnBanlistFetched)
        :SetDecodeResponse(false)
        :AddOnError(function() LoadBanlistFromFile(BANLIST_FILE_PATH) end)
        :Send()
end

--------------------------------
-- [[ Connection Filter ]]
--------------------------------

PEARL.ServerNetwork:AddConnectionFilter(function(userid)
    if banlist and banlist[userid] and PEARL.CONFIG.GLOBAL_BANLIST.STRICT then
        return false, "ID_DST_USER_BANNED"
    end
end, PEARL.ServerNetwork.FILTER_PRIORITY.HIGH)

PEARL.EventProcessor:AddSafeEventHandler("clientconnectionallowed", function(userid)
    PEARL.DiscordReporter:SendRawReportString(STRINGS.PEARL.LOGS.PLAYER_ON_EXT_BANLIST:format(
        MARKDOWN.codeline(userid) -- Do only push the warning if we are sure the player has actually passed.
    ))
end)

--------------------------------
-- [[ Setup ]]
--------------------------------

-- Only download the new version on first complete instance (number 2)
local request
if PEARL.INIT_FULL then
    request = FetchBanlistFromURL(BANLIST_URL)
end

-- If we didn't download the new version from the internet,
-- at least try to load the saved version.
if not request then
    LoadBanlistFromFile(BANLIST_FILE_PATH)
end
