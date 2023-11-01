--[[====================================================[==[
    The 'Pearl' - modification software for
    the game 'Don't Starve Together' by Klei Entertainment.

    Copyright (c) 2023 Fi7iP
    All rights reserved.

    This file is part of the 'Pearl' software shared under
    the terms of RECEX SHARED SOURCE LICENSE (version 1.0).
    See LICENSE and AUTHORS for more details.
--]==]====================================================]]


------------------------------------------
-- [[ Constants ]]
------------------------------------------

local ENDPOINT = {
    A_OWNER_LOOKUP = "https://login.kleientertainment.com/login/FamilySharingLookup",
    A_LINK_VALIDATE = "https://login.kleientertainment.com/ValidateThirdPartyLink",
}

local QUERY_TIMEOUT = 10

------------------------------------------
-- [[ Class Declaration ]]
------------------------------------------

--- @class KleiAccounts
local KleiAccounts = {}

------------------------------------------
-- [[ Static ]]
------------------------------------------

--- We are currently supporting link validation only for the discord platform account links.
KleiAccounts.PLATFORM = {
    DISCORD = "discord",
}

KleiAccounts.GAME = {
    DST = "DontStarveTogether",
}

------------------------------------------
-- [[ Public Methods ]]
------------------------------------------

--- @return Request? request The newly created request for the query.
function KleiAccounts:QueryGameOwner(userid, gameid, cb)
    local success_encode, input_json = pcall(json.encode, {
        Token   = PEARL.SERVER_TOKEN,
        KU      = userid,
        Game    = tostring(gameid),
    })
    if not success_encode or not input_json then
        return PEARL.error("JSON failed to encode query data!")
    end

    return (PEARL.HTTPClient:POST(
        ENDPOINT.A_OWNER_LOOKUP, nil, input_json, QUERY_TIMEOUT
    )):SetOnComplete(function(data, request, success)
        if not success and request:IsRetryable() then
            return
        end

        cb(success and not data.Error and data.ParentAccount)
    end)
end

--- @return Request? request The newly created request for the query.
function KleiAccounts:QueryLinkValidation(userid, platform, platformid)
    local PlatformID = string.capitalize(platform).."ID"
    local success_encode, input_json = pcall(json.encode, {
        Token           = PEARL.SERVER_TOKEN,
        UserID          = userid,
        [PlatformID]    = tostring(platformid)
    })
    if not success_encode or not input_json then
        return PEARL.error("JSON failed to encode query data!")
    end

    return (PEARL.HTTPClient:POST(
        ENDPOINT.A_LINK_VALIDATE, nil, input_json, QUERY_TIMEOUT
    ))
end

------------------------------------------
-- [[ Return ]]
------------------------------------------

return KleiAccounts
