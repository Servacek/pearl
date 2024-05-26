--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


--------------------------------------
-- [[ Constants ]]
--------------------------------------

local ROOT = PEARL.ModPersistence:GetRootDirectoryPath()
local FILENAME = tostring(PEARL.CONFIG.EMOJI_SERVER.FILENAME or "discord_emoji_cache.json")
local FILEPATH = io.extensure(ROOT.."/"..FILENAME, ".json")
local EMOJI_LIST = PEARL.ICONS.INVENTORY

--------------------------------------
-- [[ Local Variables ]]
--------------------------------------

local is_loaded = false

--------------------------------------
-- [[ Local Functions ]]
--------------------------------------

local function LoadEmojiList(emoji_list)
    PEARL.info("Loading the fallback emoji list...")

    local loaded, errmsg = json.load(FILEPATH)
    if type(loaded) == "table" then
        table.update(emoji_list, loaded)
        is_loaded = true
    else
        PEARL.error("Loading emoji list failed!", errmsg)
    end
end

local function SaveEmojiList(emoji_list)
    json.dump(emoji_list, FILEPATH)
end

local function OnFetchingSuccess(emojis)
    for name, emoji in pairs(emojis) do
        EMOJI_LIST[name] = emoji.code
    end

    is_loaded = true
    SaveEmojiList(EMOJI_LIST)
end

local function OnFetchingFailed(response, request)
    if not request:IsRetryable() and not is_loaded then
        LoadEmojiList(EMOJI_LIST)
    end
end

local function DoUpdate()
    PEARL.info("Downloading the newest emoji list from the server.")

    PEARL.HTTPClient:GET(PEARL.CONFIG.EMOJI_SERVER.URL)
        :AddOnSuccess(OnFetchingSuccess)
        :AddOnError(OnFetchingFailed)
        :Send()
end

--------------------------------------
-- [[ Global Functions ]]
--------------------------------------

--- Make this one global so it can be used from the console.
PEARL.UpdateEmojiFallbacks = DoUpdate

--------------------------------------
-- [[ Setup ]]
--------------------------------------

if PEARL.INIT_FULL and PEARL.CONFIG.EMOJI_SERVER.AUTOUPDATE and TheShard:IsMaster() then
    DoUpdate()
else
    LoadEmojiList(EMOJI_LIST)
end
