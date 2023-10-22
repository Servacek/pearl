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


--[[
    Standalone module for identifing alternative accounts of players using
    Klei's built-in API. Alt accounts with banned root will be banned as well.

    Uses the database to cache verified accounts.
]]

local TheNet = TheNet

--------------------------------
-- [[ Constants ]]
--------------------------------

local QUERY_RETRY_TIME    = 5
local QUERY_MAX_RETRIES   = 3
local QUERY_ERRORS        = {
    -- Getting this error in production usage most likely indicates
    -- some nasty formatting issues.
    INVALID_KU         = "E_INVALID_KU",
    OWNERSHIP_MISSING  = "E_OWNERSHIP_MISSING",
}

local DO_NOT_RETRY_ERRORS = {
    ["E_INVALID_KU"] = true,
    ["E_OWNERSHIP_MISSING"] = not PEARL.CONFIG.DEBUG_MODE,
}

--------------------------------
-- [[ Private ]]
--------------------------------

--- Returns true when the rootid is banned otherwise false.
--- @param userid string The ID of the user's borrowed account.
--- @param rootid string The ID of the borrower's account.
local function HasAccountInvalidRoot(userid, rootid)
    -- If the owner of the borrowed game is on our blacklist
    -- we want to ban their alt accounts as well
    -- Note: "ms_clientauthenticationcomplete" is not called for banned players.
    return rootid ~= userid and PEARL.BlackList:Contains(rootid)
end

local function GetSavedRootFor(userid)
    return PEARL.PlayerDB:GetField(userid, "rootuserid")
end

local function ShouldCheckClient(userid)
    return (
        PEARL.ServerNetwork:IsClientJoining(userid) or
        PEARL.ServerNetwork:IsClientPriviliged(userid)
    )
end

local function RunRootFilterFor(userid, rootid, filtercb)
    if type(rootid) ~= "string" then
        filtercb(true)

        return PEARL.error("Invalid root Klei ID for user", userid, "provided!")
    end

    if HasAccountInvalidRoot(userid, rootid) then
        PEARL.WallScheduler:ExecuteInTime(3, function()
            PEARL.info("Banning", userid, "for being an alt account of banned", rootid)
            TheNet:Ban(userid)
        end)

        return filtercb(false, "ID_DST_BANNED_ROOT")
    end

    PEARL.debug("Account", userid, "has a valid root ("..rootid..").")
    return filtercb(true)
end

--------------------------------
-- [[ Query ]]
--------------------------------

local function OnGameOwnerQueryFailed(response, http_code, request, userid)
    PEARL.error("Query failed with status code", http_code, "for user", userid)

    -- Try to log this error to discord as well.
    if not table.contains(QUERY_ERRORS, response.ErrorCode)then
        PEARL.DiscordReporter:ReportFailedHTTPRequest("AO Query for "..tostring(userid).." failed with error code "..(http_code or "UNKNOWN"))
    end

    -- When an error occurs, try to send the request one more time
    if request:IsRetryable() and not DO_NOT_RETRY_ERRORS[response.ErrorCode] then
        PEARL.HTTPClient:RetryRequestAfter(request, QUERY_RETRY_TIME)
    end
end

local function OnQueryCompleted(response, success, code, request, userid, oncomplete)
    local valid = type(response) == "table"

    -- response.Error refers to a boolean
    if not success or not valid or response.Error == true then
        OnGameOwnerQueryFailed(response, response.ErrorCode or -1, request, userid)
    end

    oncomplete(response and valid and response.ParentAccount)
end

--------------------------------
-- [[ Local Functions ]]
--------------------------------

local function SendRootRetriveQuery(userid, oncomplete)
    local query = PEARL.KleiAccounts:QueryGameOwner(userid, PEARL.KleiAccounts.GAME.DST)
    if not query then
        PEARL.error("Failed to create the game owner query!")
        return oncomplete(true) -- Allow the connection on error
    end

    query:SetOnComplete(OnQueryCompleted, userid, oncomplete)
    query:SetMaxRetries(QUERY_MAX_RETRIES)
    query:Send()
end

--------------------------------
-- [[ Setup ]]
--------------------------------

PEARL.ServerNetwork:AddAsyncConnectionFilter(function(userid, data, filtercb)
    if not (ShouldCheckClient(userid) or PEARL.CONFIG.DEBUG_MODE) then
        return filtercb(true)
    end

    local saved_rootid = GetSavedRootFor(userid)
    if type(saved_rootid) == "string" then
        PEARL.debug("Using saved rootid...")
        return RunRootFilterFor(userid, saved_rootid, filtercb)
    end

    PEARL.debug("Rootid not saved, sending query to retrieve it...")
    SendRootRetriveQuery(userid, function(rootid)
        -- Root ID should not change since userid is bound to it.
        -- Save it even if it's invalid so we do not have to send another query in the future.
        PEARL.PlayerDB:SafeSetField(userid, "rootuserid", rootid)

        RunRootFilterFor(userid, rootid, filtercb)
    end)
end, nil, nil, "altdentifier")
