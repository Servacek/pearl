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

    Uses a cache for verified accounts.

    TODOS: (v2.1)
        - Make the cache persistent?
        - Load the token from token.txt
]]

local json = json
local TheNet = TheNet

--------------------------------
-- [[ Constants ]]
--------------------------------

local FS_ROOT_CACHE_MAX_SIZE = 100
local FS_QUERY_TIMEOUT       = 10
-- Initialized later after FE
--- @type string
local FS_QUERY_SERVER_TOKEN

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

--- @type table<string>
local fs_root_cache = createTable(FS_ROOT_CACHE_MAX_SIZE)

local function IsUserIDCached(userid)
    for i = 1, #fs_root_cache do
        if fs_root_cache[i] == userid then
            return true
        end
    end

    return false
end

--- Adds the given userid to the cache so it will be counted as valid.
--- @param userid string The target valid userid to be cached.
local function CacheRootUserid(userid)
    if IsUserIDCached(userid) then
        return
    end

    if #fs_root_cache >= FS_ROOT_CACHE_MAX_SIZE then
        table.remove(fs_root_cache, 1)
    end

    table.insert(fs_root_cache, userid)
end

--- Returns false when the rootid is banned and bans userid as well,
--- otherwise returns true and does nothing.
--- @param userid string The ID if the user's borrowed account.
--- @param rootid string The ID of the borrower's account.
local function HasAccountValidRoot(userid, rootid)
    -- If the owner of the borrowed game is on our blacklist
    -- we want to ban their alt accounts as well
    -- Note: "ms_clientauthenticationcomplete" is not called for banned players.
    return rootid == userid or not PEARL.BlackList:Contains(rootid)
end

local function ShouldCheckClient(userid)
    return (
        not IsUserIDCached(userid) and
        not PEARL.AdminList:Contains(userid) and
        not TheNet:GetUserID() == userid
    )
end

--------------------------------
-- [[ Query ]]
--------------------------------

local HandleFSQuery, SendFSQueryFor

HandleFSQuery = function(response, success_query, http_code, request, userid, no_retry)
    if not success_query or not response then
        -- Try to log this error to discord as well.
        if not no_retry then
            PEARL.DiscordReporter:ReportFailedHTTPRequest("AO Query for "..tostring(userid).." failed with error code "..(http_code or "UNKNOWN"))
        end

        return PEARL.error("Query failed with status code", http_code, "for user", userid)
    end

    -- PEARL.debug(
    --     "RESPONSE", response,
    --     "USERID:", userid,
    --     "NO_RETRY:", no_retry,
    --     "SUCCESS:", success_query,
    --     "CODE:", http_code,
    --     "REQUEST:", request
    -- )
    local success_decode, reponse_json = pcall(json.decode, response)
    if not success_decode or not reponse_json then
        return PEARL.error("JSON decoding failed for user", userid)
    end

    -- reponse_json.Error refers to a boolean
    if reponse_json.Error then
        PEARL.error("Query for", userid, "failed with error code", reponse_json.ErrorCode or "UNKNOWN")

        -- If the error is unknown then report it to discord.
        if not no_retry and not table.contains(QUERY_ERRORS, reponse_json.ErrorCode) then
            PEARL.DiscordReporter:ReportFailedHTTPRequest("AO Query for "..userid.." failed with unknown error code "..(reponse_json.ErrorCode or "UNKNOWN"))
        end

        -- When an error occurs, try to send the request one more time
        if not no_retry and not DO_NOT_RETRY_ERRORS[reponse_json.ErrorCode] then
            PEARL.info("Retrying request...")
            return SendFSQueryFor(userid, true)
        end

        return
    end

    local rootid = reponse_json.ParentAccount
    if not rootid then
        return PEARL.info("No root account info for user", userid)
    end

    if not HasAccountValidRoot(userid, rootid) then
        if TheWorld then
            TheWorld:PushModEvent("clientconnectionclosed", {
                reason = "ID_DST_BANNED_ROOT",
                userid = userid,
            })
        end

        PEARL.info("Banning", userid, "for being an alt account of banned", rootid)
        return TheNet:Ban(userid)
    end

    -- If verification was successfull, cache this userid to
    -- reduce the number of queries.
    PEARL.debug("Account", userid, "has a valid root. Caching...")
    CacheRootUserid(userid)
end

SendFSQueryFor = function(userid, no_retry)
    local success_encode, input_json = pcall(json.encode, {
        Token = FS_QUERY_SERVER_TOKEN,
        KU = userid,
        Game = "DontStarveTogether"
    })
    if not success_encode or not input_json then
        return PEARL.error("JSON failed to encode query data!")
    end

    PEARL.HTTPClient:POST(
        PEARL.CONSTS.FSLS_QUERY_URL, HandleFSQuery,
        input_json, FS_QUERY_TIMEOUT, userid, no_retry or false
    ):Send()
end

--------------------------------
-- [[ Setup ]]
--------------------------------

PEARL.AddWorldPostInit(function(world)
    if not world then
        return
    end

    -- Pushed during world migration as well, such event's should be filtered out
    -- by the cache.
    world:SafeListenForEvent("ms_clientauthenticationcomplete", function(_, data)
        if not (data and data.userid) then
            return
        end

        if ShouldCheckClient(data.userid) or PEARL.CONFIG.DEBUG_MODE then
            SendFSQueryFor(data.userid)
        end
    end)
end)

-- Load the server token here
PEARL.AddFrontEndPostInit(function(fe)
    if not fe then
        return
    end

    PEARL.info("FrontEnd loaded. Loading server token...")
    local account_manager = fe:GetAccountManager()
    if account_manager and account_manager:HasAuthToken() then
        FS_QUERY_SERVER_TOKEN = account_manager:GetToken()
    end

    if not FS_QUERY_SERVER_TOKEN then
        return error("Could not load the server token!")
    end

    PEARL.info("Success!")
end)
