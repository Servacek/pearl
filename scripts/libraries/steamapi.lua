--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
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

-------------------------------------
-- [[ Class Declaration ]]
-------------------------------------

--- @class SteamAPI
local SteamAPI = {
    --- @type table<steamid, table<function, table<number, any>|number>>
    _query_sequences = {}
}

-------------------------------------
-- [[ Static ]]
-------------------------------------

SteamAPI.QUERIES = {
    P_BANS          = "https://api.steampowered.com/ISteamUser/GetPlayerBans/v1/?key="..PEARL.CONFIG.STEAM.API_KEY.."&steamids=%s",
    P_SUMMARIES     = "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key="..PEARL.CONFIG.STEAM.API_KEY.."&steamids=%s",
    P_NAMEHISTORY   = "https://steamcommunity.com/profiles/%s/ajaxaliases",
    P_PLAYTIME      = "https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/?key="..PEARL.CONFIG.STEAM.API_KEY.."&steamid=%s&include_played_free_games=1&appids_filter[0]=%s&include_free_sub=1",
    P_COMMENTS      = "https://steamcommunity.com/comment/Profile/render/%s/-1/?start=0&count=%d",
    P_FRIENDLIST    = "https://api.steampowered.com/ISteamUser/GetFriendList/v0001/?key="..PEARL.CONFIG.STEAM.API_KEY.."&steamid=%s&relationship=friend",
}

-------------------------------------
-- [[ Local Functions ]]
-------------------------------------

local function HandleQueryResult(query, result)
    if type(query.cb) == "function" then
        return query.cb(result)
    end
end

local function OnQueryFinished(result, request, steamid, index)
    local seq = SteamAPI._query_sequences[steamid]
    if not seq then
        return PEARL.error("Query finished for invalid sequence!")
    end

    local query = seq[index]
    if not query then
        return PEARL.error("Invalid query finished!")
    end

    seq[index] = nil

    -- We do not care if this errors, our work here is to just call it.
    HandleQueryResult(query, result)

    if #seq == 0 then
        SteamAPI:RemoveDataQuerySequenceFor(steamid)

        if type(seq.finishcb) == "function" then
            seq.finishcb()
        end
    end
end

-------------------------------------
-- [[ Public Methods ]]
-------------------------------------

function SteamAPI:AddQueryToSequence(steamid, url, cb, ...)
    if type(self._query_sequences[steamid]) ~= "table" then
        return PEARL.error("Invalid sequence", steamid)
    end

    local qr = {
        url = url,
        cb = cb,
        args = toarray(...),
    }
    self._query_sequences[steamid][#self._query_sequences[steamid] + 1] = qr

    return qr
end

function SteamAPI:AddRawQueryToSequence(steamid, query, cb, ...)
    local qr = self:AddQueryToSequence(steamid, query, cb, ...)
    qr.raw = true

    return qr
end

function SteamAPI:RemoveDataQuerySequenceFor(steamid)
    self._query_sequences[steamid] = nil
end

function SteamAPI:CreateDataQuerySequenceFor(steamid, finishcb)
    if type(self._query_sequences[steamid]) ~= "table" then
        self._query_sequences[steamid] = {
            finishcb = finishcb
        }
    end
end

function SteamAPI:ExecuteDataQuerySequenceFor(steamid)
    if type(self._query_sequences[steamid]) ~= "table" then
        return PEARL.error("Attempted to execute an invalid query sequence.")
    end

    local query
    local seq = self._query_sequences[steamid]
    for i = #seq, 1, -1 do
        query = seq[i]

        if query then
            PEARL.HTTPClient:GET(
                query.url:format(steamid, unpack(query.args)), OnQueryFinished, nil, steamid, i
            ):SetIsRaw(query.raw):Send(true)
        end
    end
end

function SteamAPI:DeleteDataQuerySequenceFor(steamid)
    self._query_sequences[steamid] = nil
end

-------------------------------------
-- [[ Return ]]
-------------------------------------

return SteamAPI
