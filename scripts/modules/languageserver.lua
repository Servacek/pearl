--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @category Frontend


--------------------------------------
-- [[ Constants ]]
--------------------------------------

local URL = PEARL.CONFIG.LANGUAGE_SERVER.URL
local LANGUAGE = tostring(PEARL.CONFIG.LANGUAGE_SERVER.LANGUAGE)
local FILENAME = tostring(PEARL.CONFIG.LANGUAGE_SERVER.FILENAME or LANGUAGE.."_cache.po")
local FILE_PATH = io.extensure(PEARL.SRCDIR.."/languages/cache/"..tostring(FILENAME), ".po")

local DEFERANT = "translation"

local IS_JOINING = not PEARL.ClientNetwork:HasSentCFD()

--------------------------------------
-- [[ Local Functions ]]
--------------------------------------

local function SaveTranslation(podata)
    PEARL.info("Saving downloaded translation to local file...")

    local wf = io.open(FILE_PATH, "w")
    if not wf then
        return PEARL.error("Failed to open", FILE_PATH)
    end

    wf:write(podata)
    wf:close()
end

local function LoadTranslation()
    PEARL.info("Loading and applying translations from local file...")

    return LoadPOFile(FILE_PATH, LANGUAGE)
end

local function OnDownloadQueryCompleted()
    -- Continue loading the client, we do not care about the result here...
    PEARL.ClientLoader:RemoveDeferant(DEFERANT)
end

local function OnDownloadQueryFailed()
    LoadTranslation()
end

local function OnTranslationDownloaded(podata)
    PEARL.info("Successufully downloaded translation from the language server!")

    SaveTranslation(podata)
    LoadTranslation()
end

--------------------------------------
-- [[ Handlers ]]
--------------------------------------

--- If we have not yet sent the CFD data to the server it means we are joining the server.
if (IS_JOINING and PEARL.CONFIG.LANGUAGE_SERVER.AUTOUPDATE) or not io.exists(FILE_PATH) then
    PEARL.info("Requesting newest version of the translation from the configured server...")

    PEARL.HTTPClient:GET(URL, OnTranslationDownloaded)
        :SetOnComplete(OnDownloadQueryCompleted)
        :SetOnError(OnDownloadQueryFailed)
        :SetIsRaw(true)
        :Send()

    PEARL.ClientLoader:AddPreLoadHandler(function()
        PEARL.ClientLoader:AddDeferant(DEFERANT)
    end)
else
    PEARL.info("Applying translation from local file...")

    LoadTranslation()
end
