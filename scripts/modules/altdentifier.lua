--[[
    Standalone module for identifing alternative accounts of players using
    Klei's built-in API. Alt accounts with banned root will be banned as well.

    Uses a cache for verified accounts.

    TODOS: (v2.1)
        - Make the cache persistent?
]]

local json = json
local PEARL = PEARL
local TheNet = TheNet

--------------------------------
-- [[ Constants ]]
--------------------------------

local FS_ROOT_CACHE_MAX_SIZE = 100
local FS_QUERY_TIMEOUT       = 10
-- Initialized later after FE
local FS_QUERY_SERVER_TOKEN

local QUERY_ERRORS        = {
    -- Getting this error in production usage most likely indicates
    -- some nasty formatting issues. Maybe it would be a good idea to
    -- report it to discord.
    INVALID_KU         = "E_INVALID_KU",
    OWNERSHIP_MISSING  = "E_OWNERSHIP_MISSING",
}

local DO_NOT_RETRY_ERRORS = {
    ["E_INVALID_KU"] = true,
    ["E_OWNERSHIP_MISSING"] = true,
}

--------------------------------
-- [[ Private ]]
--------------------------------

-- So it is read only
local fs_root_cache = {}
local fs_root_cache_size = 0

local CacheRootUserid, GetCachedRootUserid, HandleFSQuery, SendFSQueryFor, VerifyRootUserid

CacheRootUserid = function(userid, rootid)
    if fs_root_cache_size <= FS_ROOT_CACHE_MAX_SIZE then
        fs_root_cache[userid] = rootid

        local cached_rootid = GetCachedRootUserid(userid)
        if cached_rootid ~= nil and cached_rootid ~= rootid then
            PEARL.warn(userid, " already cached! Root id was overriden.")
        else
            fs_root_cache_size = fs_root_cache_size + 1
        end
    end
end

GetCachedRootUserid = function(userid)
    return fs_root_cache[userid]
end

-- Returns false when the rootid is banned and bans userid as well,
-- otherwise returns true and does nothing.
VerifyRootUserid = function(userid, rootid)
    -- If the owner of the borrowed game is on our blacklist
    -- we want to ban their alt accounts as well
    -- Note: "ms_clientauthenticationcomplete" is not called for banned players.
    if rootid ~= userid and PEARL.TheBlackList:IsBlacklisted(rootid) then
        PEARL.DiscordLogger.OnAltClientWithBannedRoot(userid, rootid)

        PEARL.info("Banning", userid, "for being an alt account of banned", rootid)
        TheNet:Ban(userid)

        return false
    end

    return true
end

HandleFSQuery = function(response, success_query, http_code, request, userid, no_retry)
    if not success_query or not response then
        return PEARL.error("Query failed with status code", http_code, "for user", userid)
    end

    -- PEARL.debug(
    --     "USERID:", userid,
    --     "NO_RETRY:", no_retry,
    --     "RESPONSE:", reponse,
    --     "SUCCESS:", success_query,
    --     "CODE:", http_code,
    --     "REQUEST:", request
    -- )
    local success_decode, reponse_json = pcall(json.decode, response)
    if not success_decode or not reponse_json then
        return PEARL.error("JSON decoding failed for user", userid)
    end

    --table.foreach(reponse_json, SUB.debug)
    -- reponse_json.Error refers to a boolean
    if reponse_json.Error then
        PEARL.error("Query for", userid, "failed with error code", reponse_json.ErrorCode or "UNKNOWN")

        -- If the error is unknown then report it to discord.
        if not QUERY_ERRORS[reponse_json.ErrorCode] then
            PEARL.Rhook:SendErrorReport("AO Query for "..userid.." failed with error code "..(reponse_json.ErrorCode or "UNKNOWN"))
        end

        -- When an error occurs, try to send the request one more time
        print("NO_RETRY:", tostring(no_retry))
        if not no_retry and not DO_NOT_RETRY_ERRORS[reponse_json.ErrorCode] then
            PEARL.info("Retrying request...")
            return SendFSQueryFor(userid, true)
        end

        return
    end

    local rootid = reponse_json.ParentAccount
    if not rootid then
        return PEARL.info("Blacklist", "No root account info for user", userid)
    end

    local valid_root = VerifyRootUserid(userid, rootid)
    PEARL.debug("USERID:", userid, "ROOTID:", rootid, "VALID:", tostring(valid_root))
    if valid_root then
        -- If verification was successfull, cache this userid to
        -- reduce the number of queries.
        PEARL.info("Blacklist", "Account", userid, "has a valid root. Caching...")
        CacheRootUserid(userid, rootid)
    end
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

    print("NO_RETRY", tostring(no_retry))
    PEARL.RestClient:POST(
        PEARL.CONSTS.FSLS_QUERY_URL, HandleFSQuery,
        input_json, FS_QUERY_TIMEOUT, userid, no_retry or false
    ):Send()
end

--------------------------------
-- [[ Setup ]]
--------------------------------

PEARL.AddWorldPostInit(function(world)
    world:ListenForEvent("ms_clientauthenticationcomplete", function(_, userid)
        if not userid or PEARL.IsClientMigrating(userid) then
            return
        end

        if not GetCachedRootUserid(userid) then
            SendFSQueryFor(userid)
        end
    end)
end)

-- Load the server token here
AddGlobalClassPostConstruct("frontend", "FrontEnd", function(frontend)
    if not frontend then
        return
    end

    PEARL.info("FrontEnd loaded. Loading server token...")
    local account_manager = frontend:GetAccountManager()
    if account_manager and account_manager:HasAuthToken() then
        FS_QUERY_SERVER_TOKEN = account_manager:GetToken()
    end

    if not FS_QUERY_SERVER_TOKEN then
        return error("Could not load the server token!")
    end

    PEARL.info("Success!")
end)
