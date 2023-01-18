--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @category BackEnd


-- NOTE: All of this on the client's side needs to be executed in one tick!


local TheSim = TheSim
local table = table

--------------------------------
-- [[ Contants ]]
--------------------------------

local CACHE_FILE_NAME = "loc_uids_cache"
local CACHE_MAX_SIZE = 2^4
local CACHE_ENCODE = false
local ID_SEPARATOR = "|"

--------------------------------
-- [[ Private - Server Side ]]
--------------------------------

--- @type table<string>
local client_userid_cache = {}

--- @type table<string, Task>
local timeouts = {}

--------- TIMEOUT ------------

local function CancelTimeoutFor(userid)
    --PEARL.debug("_CancelTimeoutFor", userid)

    if timeouts[userid] ~= nil then
        timeouts[userid]:Cancel()
        timeouts[userid] = nil
    end
end

local function OnTimeout(userid)
    --PEARL.debug("_OnTimeout", userid)

    CancelTimeoutFor(userid)

    --- @TODO: Maybe send this info to discord as well?
    PEARL.warn("The localization process for client ", userid, "has timed out.")

    --- @TODO:
    -- Safe-Fall - do nothing for now, but in the future it would
    -- be a good idea to disconnect such connections
    --PEARL.ServerNetwork:SendUserDisconnectFor(userid, "ID_DISCONNECTION_NOTIFICATION")
end

local function StartTimeoutFor(userid)
    --PEARL.debug("_StartTimeoutFor", userid)

    -- If there is already an timeout task scheduled do not reset it
    if timeouts[userid] then
        return
    end

    timeouts[userid] = PEARL.Scheduler:ExecuteInTime(
        PEARL.CONSTS.LOCALIZATION_TIMEOUT, OnTimeout, nil, userid
    )
end

--------- CACHE ------------

local function IsClientCached(userid)
    if not client_userid_cache or not PEARL.CONFIG.LOCALIZER_CACHE then
        return false
    end

    for _, cached_userid in ipairs(client_userid_cache) do
        if cached_userid == userid then
            return true
        end
    end

    return false
end

-- Returns an empty string if the cache is empty.
local function BuildPersistentStringForCache()
    return table.concat(client_userid_cache, ID_SEPARATOR)
end

local function SavePersistentCache()
    if #client_userid_cache <= 0 then
        return
    end

    return TheSim:SetPersistentString(
        CACHE_FILE_NAME, BuildPersistentStringForCache(), CACHE_ENCODE
    )
end

-- Should be called just once - on start
local function LoadPersistentCache()
    SavePersistentCache()
    if not kleifileexists(CACHE_FILE_NAME) then
        return PEARL.debug("Missing the cache file.")
    end

    TheSim:GetPersistentString(CACHE_FILE_NAME, function(success, data)
        if not success or not data then
            return PEARL.error("Failed to load the cache!")
        end

        client_userid_cache = data:split(ID_SEPARATOR)
    end, CACHE_ENCODE)
end

local function CacheLocalizedClient(userid)
    if not client_userid_cache then
        client_userid_cache = {}
    end

    table.insert(client_userid_cache, userid)

    if #client_userid_cache > CACHE_MAX_SIZE then
        table.remove(client_userid_cache, 1)
    end
end

--------- HANDLERS ------------

local function OnClientDisconnected(userid)
    -- PEARL.debug("OnClientDisconnected")

    CancelTimeoutFor(userid)
end

local function OnClientAuthenticationComplete(userid)
    if type(userid) ~= "string" then
        return
    end

    -- PEARL.debug("OnClientAuthenticationComplete")

    StartTimeoutFor(userid)
end

-- Save the cache when we are shutting down
local function OnShutdown()
    SavePersistentCache()
end

--------------------------------
-- [[ Setup - Server ]]
--------------------------------

PEARL.ServerNetwork:AddClientConnectionFilter(function(userid, cfd)
    local locale = cfd and string.upper(cfd.locale)
    if not locale then
        return
    end

    PEARL.info("Client", userid, "localized as", cfd.locale)
    CancelTimeoutFor(userid)

    -- If the player was already loaded we do not care about localization.
    -- This happens for example during migration.
    if IsClientCached(userid) or
        PEARL.AllowList:Contains(userid) or
        PEARL.WhiteList:Contains(userid) or
        (PEARL.AdminList:Contains(userid) and not PEARL.CONFIG.DEBUG_MODE)
    then
        PEARL.debug("Client allowed.")
        return true -- Allow the connection
    end

    -- Check only if the locale is allowed explicitly
    -- So by default everything is prohibited
    -- Everything else should be checked before sending the localization request
    -- Cache only successfull localizations.
    if PEARL.CONFIG.LOCALIZER.ALLOWED_LOCALES[locale] == true or table.contains(PEARL.CONFIG.LOCALIZER.ALLOWED_LOCALES, locale) then
        PEARL.info("Locale allowed.")

        if PEARL.CONFIG.LOCALIZER_CACHE then
            PEARL.info("Caching localized userid...")
            CacheLocalizedClient(userid)
        end

        return true -- Allow the connection
    end

    PEARL.info("Locale prohibited.")
    -- Do not allow further loading
    return false, "ID_DST_LOCALE_BLOCKED"
end)

LoadPersistentCache()

--------------------------------
-- [[ Event Listeners ]]
--------------------------------

PEARL.EventProcessor:AddEventHandler(
    "ms_clientdisconnected", OnClientDisconnected
)

PEARL.EventProcessor:AddEventHandler(
    "clientconnectionclosed", OnClientDisconnected
)

PEARL.EventProcessor:AddEventHandler(
    "ms_clientauthenticationcomplete", OnClientAuthenticationComplete
)

PEARL.EventProcessor:AddEventHandler(
    "quit", OnShutdown
)
