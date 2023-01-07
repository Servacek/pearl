--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]
--- @category FrontEnd & BackEnd


-- NOTE: All of this on the client's side needs to be executed in one tick!


local PEARL = PEARL

local TheNet, TheSim = TheNet, TheSim
local table = table

--------------------------------
-- [[ Contants ]]
--------------------------------

local LOCALE_PATTERN = "&locale=(%w+)&"
local CACHE_FILE_NAME = "loc_uids_cache"
local CACHE_MAX_SIZE = 2^4
local CACHE_ENCODE = false
local ID_SEPARATOR = "|"

local CLIENT_LOAD_WAIT_DELAY = 30 * FRAMES

--------------------------------
-- [[ Private - Client Side ]]
--------------------------------

--- @return string? locale The locale of this machine or nil if we have failed to fetch it.
local function _GetLocale()
    local motd_url = TheSim:GetMOTDQueryURL()
    if type(motd_url) ~= "string" then
        return
    end

    local locale = motd_url:match(LOCALE_PATTERN)
    if type(locale) ~= "string" then
        return
    end

    return locale:upper()
end

local function _Localize()
    local locale = _GetLocale()
    if type(locale) ~= "string" then
        return PEARL.error("Failed to fetch the locale!")
    end

    PEARL.SendRPCToServer(PEARL.RPCS.ClientLocalizationCompleted, locale)
end

local function _OnLocaleAllowed()
    if PEARL.ClientLoader:HasLoadDelayStarted() then
        PEARL.debug("_OnLocaleAllowed")
        return PEARL.ClientLoader:Load()
    end
end

--------------------------------
-- [[ Private - Server Side ]]
--------------------------------

--- @type table<string>?
local _client_userid_cache

--- @type table<string, Task>
local _timeouts = {}

--------- TIMEOUT ------------

local function _CancelTimeoutFor(userid)
    PEARL.debug("_CancelTimeoutFor", userid)

    if _timeouts[userid] ~= nil then
        _timeouts[userid]:Cancel()
        _timeouts[userid] = nil
    end
end

local function _OnTimeout(userid)
    PEARL.debug("_OnTimeout", userid)

    _CancelTimeoutFor(userid)

    PEARL.warn("The localization process for client ", userid, "has timed out.")
    -- Safe-Fall - do nothing for now, but in the future it would
    -- be a good idea to disconnect such connections
    --PEARL.ServerNetwork:SendUserDisconnectFor(userid, "ID_DISCONNECTION_NOTIFICATION")
end

local function _StartTimeoutFor(userid)
    PEARL.debug("_StartTimeoutFor", userid)

    -- If there is already an timeout task scheduled do not reset it
    if _timeouts[userid] then
        return
    end

    _timeouts[userid] = PEARL.Scheduler:ExecuteInTime(
        PEARL.CONSTS.LOCALIZATION_TIMEOUT, _OnTimeout, nil, userid
    )
end

--------- CACHE ------------

local function _IsClientCached(userid)
    if not _client_userid_cache then
        return false
    end

    for _, cached_userid in ipairs(_client_userid_cache) do
        if cached_userid == userid then
            return true
        end
    end

    return false
end

-- Should be called just once - on start
local function _LoadPersistentCache()
    TheSim:GetPersistentString(CACHE_FILE_NAME, function(success, data)
        if not success or not data then
            PEARL.error("Failed to load the cache!")
        end

        _client_userid_cache = data:split(ID_SEPARATOR)
    end, CACHE_ENCODE)
end

local function _BuildPersistentStringForCache()
    return table.concat(_client_userid_cache, ID_SEPARATOR)
end

local function _SavePersistentCache()
    if #_client_userid_cache <= 0 then
        return
    end

    return TheSim:SetPersistentString(
        CACHE_FILE_NAME, _BuildPersistentStringForCache(), CACHE_ENCODE
    )
end

local function _CacheLocalizedClient(userid)
    if not _client_userid_cache then
        _client_userid_cache = {}
    end

    table.insert(_client_userid_cache, userid)

    if #_client_userid_cache > CACHE_MAX_SIZE then
        table.remove(_client_userid_cache, 1)
    end
end

--------- HANDLERS ------------

local function _OnClientDisconnected(userid)
    PEARL.debug("_OnClientDisconnected")

    _CancelTimeoutFor(userid)
end

local function _OnClientAuthenticationComplete(userid)
    if type(userid) ~= "string" then
        return
    end

    PEARL.debug("_OnClientAuthenticationComplete")

    _StartTimeoutFor(userid)
end

-- Client is being localized on every load.
local function _OnClientLocalizationComplete(userid, locale)
    PEARL.debug("_OnClientLocalizationComplete")

    _CancelTimeoutFor(userid)

    -- If the player was already loaded we do not care about localization.
    -- This happens for example during migration.
    if _IsClientCached(userid) or
        PEARL.AllowList:Contains(userid) or
        PEARL.WhiteList:Contains(userid)
    then
        PEARL.debug("_OnClientLocalizationComplete: Sending local allowed rpc to client...")
        return PEARL.SendRPCToClient(PEARL.RPCS.LocaleAllowed, userid)
    end

    -- Check only if the locale is allowed explicitly
    -- So by default everything is prohibited
    -- Everything else should be checked before sending the localization request
    -- Cache only successfull localizations.
    if PEARL.CONFIG.ALLOWED_LOCALES[locale] == true or table.contains(PEARL.CONFIG.ALLOWED_LOCALES, locale) then
        PEARL.info("Client successfully localized. Caching...")
        _CacheLocalizedClient(userid)

        return PEARL.SendRPCToClient(PEARL.RPCS.LocaleAllowed, userid)
    end

    PEARL.info("Client localization failed. Reason: Locale not allowed!")
    -- Do not allow further loading
    return PEARL.ServerNetwork:SendUserDisconnectFor(
        userid, "ID_DST_LOCALE_BLOCKED"
    )
end

-- Save the cage when we are shutting down
local function _OnShutdown()
    _SavePersistentCache()
end

--------------------------------
-- [[ Setup - Client ]]
--------------------------------

if TheNet:GetIsClient() then
    PEARL.EventProcessor:AddEventHandler(
        "locale_allowed", _OnLocaleAllowed
    )

    --- @TODO: Try to use default RPCS instead of the mod ones.
    -- Send our locale to the server
    -- Game logic is loaded right after RPC namespaces are registered
    -- This is so we manage to localize in the mod loading tick
    PEARL.AddGameLogicPreLoad(_Localize)

    if PEARL.ClientLoader then
        -- Send our locale to the server
        -- Wait a few ticks for the server's response
        if (PEARL.ClientLoader:GetLoadDelay() or 0) < CLIENT_LOAD_WAIT_DELAY then
            PEARL.ClientLoader:SetLoadDelay(CLIENT_LOAD_WAIT_DELAY)
        end

        -- Enable client loader
        PEARL.ClientLoader:SetIsDisabled(false)
    end

    return
end

--------------------------------
-- [[ Setup - Server ]]
--------------------------------

_LoadPersistentCache()

PEARL.EventProcessor:AddEventHandler(
    "ms_clientlocalizationcomplete", _OnClientLocalizationComplete
)

PEARL.EventProcessor:AddEventHandler(
    "ms_clientdisconnected", _OnClientDisconnected
)

PEARL.EventProcessor:AddEventHandler(
    "clientconnectionclosed", _OnClientDisconnected
)

PEARL.EventProcessor:AddEventHandler(
    "ms_clientauthenticationcomplete", _OnClientAuthenticationComplete
)

PEARL.EventProcessor:AddEventHandler(
    "quit", _OnShutdown
)
