--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023-2024 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


if type(PEARL.CONFIG.STEAM.API_KEY) ~= "string" or #PEARL.CONFIG.STEAM.API_KEY < PEARL.CONSTS.STEAM_API_KEY_LENGTH then
    return error("Invalid Steam API key provided!")
end

-------------------------------------
-- [[ Constants ]]
-------------------------------------

local STEAM_QUERY_RETRIES = 3
local STEAM_QUERY_TIMEOUT = 10

-------------------------------------
-- [[ Class Declaration ]]
-------------------------------------

--- @singleton
--- @class SteamAPI
local SteamAPI = {
    --- @type table<string, table<integer, Request>>
    _query_sequences = {}
}

-------------------------------------
-- [[ Static ]]
-------------------------------------

SteamAPI.BASE_URL       = PEARL.CONFIG.STEAM.BASE_URL
SteamAPI.BASE_API_URL   = PEARL.CONFIG.STEAM.BASE_API_URL

SteamAPI.QUERIES = {
    P_BANS          = SteamAPI.BASE_API_URL.."/ISteamUser/GetPlayerBans/v1/?key="..PEARL.CONFIG.STEAM.API_KEY.."&steamids=%s",
    P_SUMMARIES     = SteamAPI.BASE_API_URL.."/ISteamUser/GetPlayerSummaries/v0002/?key="..PEARL.CONFIG.STEAM.API_KEY.."&steamids=%s",
    P_NAMEHISTORY   = SteamAPI.BASE_URL.."/profiles/%s/ajaxaliases",
    P_PLAYTIME      = SteamAPI.BASE_API_URL.."/IPlayerService/GetOwnedGames/v1/?key="..PEARL.CONFIG.STEAM.API_KEY.."&steamid=%s&include_played_free_games=1&appids_filter[0]=%s&include_free_sub=1",
    P_COMMENTS      = SteamAPI.BASE_URL.."/comment/Profile/render/%s/-1/?start=0&count=%d",
    P_FRIENDLIST    = SteamAPI.BASE_API_URL.."/ISteamUser/GetFriendList/v0001/?key="..PEARL.CONFIG.STEAM.API_KEY.."&steamid=%s&relationship=friend",
}

SteamAPI.STATUS_CODES = {
    OK = 200,                    -- Success!
    BAD_REQUEST = 400,           -- Please verify that all required parameters are being sent.
    UNAUTHORIZED = 401,	         -- Access is denied. Retrying will not help. Please verify your key= parameter.
    FORBIDDEN = 403,	         -- Access is denied. Retrying will not help. Please verify your key= parameter.
    NOT_FOUND = 404,             -- The API requested does not exists.
    METHOD_NOT_ALLOWED = 405,	 -- This API has been called with a the wrong HTTP method like GET or PUSH.
    TOO_MANY_REQUEST = 429,      -- You are being rate limited.
    INTERNAL_SERVER_ERROR = 500, -- An unrecoverable error has occurred, please try again. If this continues to persist then please post to the Steamworks developer discussion with additional details of your request.
    SERVICE_UNAVAILABLE = 503,   -- Server is temporarily unavailable, or too busy to respond. Please wait and try again later.
}

SteamAPI.PROFILE_CONFIGURED = "1"

SteamAPI.PROFILE_VISIBILITY = {
    PUBLIC  = "3",
    PRIVATE = "1",
}

-------------------------------------
-- [[ Local Functions ]]
-------------------------------------

local function OnQueryCompleted(steamid, index, finishcb)
    local sequence = SteamAPI._query_sequences[steamid]
    if (sequence ~= nil) then
        sequence[index] = nil
        if table.empty(sequence) then
            SteamAPI._query_sequences[steamid] = nil
            if type(finishcb) == "function" then
                finishcb()
            end
        end
    end
end

local function OnNoAccess() end

-------------------------------------
-- [[ Public Methods ]]
-------------------------------------

--- @param steamid string
--- @param url string
--- @param cb fun(response: string|table)
--- @return Request query The query that was added to the sequence, or nil when it fails.
function SteamAPI:AddQueryToSequence(steamid, url, cb, ...)
    if type(self._query_sequences[steamid]) ~= "table" then
        self._query_sequences[steamid] = {}
    end

    local query = PEARL.HTTPClient:GET(
        url:format(steamid, ...), cb, STEAM_QUERY_TIMEOUT
    )
    table.insert(self._query_sequences[steamid], query)

    return query
end

--- @param steamid string
--- @param url string
--- @param cb fun(response: string|table)
--- @return Request query The query that was added to the sequence, or nil when it fails.
function SteamAPI:AddRawQueryToSequence(steamid, url, cb, ...)
    return self:AddQueryToSequence(steamid, url, cb, ...)
        :SetDecodeResponse(false)
end

--- @param finishcb fun()
--- @param steamid string
function SteamAPI:ExecuteDataQuerySequenceFor(steamid, finishcb)
    for i, query in ipairs(self._query_sequences[steamid]) do
        query
            -- These most likely mean that the users profile is set to private.
            :AddStatusCodeHandle(SteamAPI.STATUS_CODES.UNAUTHORIZED, OnNoAccess)
            :AddStatusCodeHandle(SteamAPI.STATUS_CODES.FORBIDDEN, OnNoAccess)
            :SetMaxRetries(STEAM_QUERY_RETRIES)
            :AddOnComplete(function()
                OnQueryCompleted(steamid, i, finishcb)
            end)
            :Send()
    end
end

-------------------------------------
-- [[ Return ]]
-------------------------------------

return SteamAPI
