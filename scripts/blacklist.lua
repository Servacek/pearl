setfenv(1, _G.SUB.env)
local SUB = SUB
local table = table
local TheNet, TheSim = TheNet, TheSim

-------------------------------

local BlacklistManager = {
    FS_ROOT_CACHE_MAX_SIZE = 25,
}
-- So it is read only
local fs_root_cache = {}
local fs_root_cache_size = 0

-------------------------------

function BlacklistManager.GetBlacklist()
    return TheNet:GetBlacklist() or {}
end

-- Returns true on success otherwise -> false
function BlacklistManager.RemovePlayerByID(player_id)
    local blacklist = BlacklistManager.GetBlacklist()
    for i, v in ipairs(blacklist) do
        if not v.empty and (v.userid == player_id or v.netid == player_id) then
            table.remove(blacklist, i)
            TheNet:SetBlacklist(blacklist)

            return true
        end
    end

    return false
end

function BlacklistManager.IsUserBlacklisted(userid)
    local blacklist = BlacklistManager.GetBlacklist()

    for _, user in pairs(blacklist) do
        if user.userid == userid then return true end
    end

    return false
end

function BlacklistManager.CacheRootUserid(userid, rootid)
    if fs_root_cache_size <= BlacklistManager.FS_ROOT_CACHE_MAX_SIZE then
        fs_root_cache[userid] = rootid
        fs_root_cache_size = fs_root_cache_size + 1
    end
end

function BlacklistManager.GetCachedRootUserid(userid)
    return fs_root_cache[userid]
end

function BlacklistManager.HandleFamilySharingCheckQuery(userid, output_http, success_query, http_code)
    if not success_query or http_code ~= 200 then
        return SUB.info("BlacklistManager", "Query failed with status code", http_code, "for user", userid)
    end

    local success_decode, output_json = pcall(function()
        return json.decode(output_http)
    end)

    if not success_decode or not output_json then
        return SUB.info("BlacklistManager", "JSON decoding failed for user", userid)
    end

    if output_json.Error then
        return SUB.info("BlacklistManager", "Klei API failed, server returned error for user", userid)
    end

    local rootid = output_json.ParentAccount
    if not rootid then
        return SUB.info("BlacklistManager", "No root account info for user", userid)
    end

    -- If the owner of the borrowed game is on our blacklist
    -- we want to ban their alt accounts as well
    if BlacklistManager.IsUserBlacklisted(rootid) then
        SUB.Logger.OnAltClientWithBannedRoot(userid, rootid)

        print("Banning", userid, "for being an alt account of banned", rootid)
        TheNet:Ban(userid)
        return
    end

    -- If we don't ban the userid then we try to cache it
    -- to reduce the number of queries
    BlacklistManager.CacheRootUserid(userid, rootid)
end

function BlacklistManager.SendFamilySharingCheckQueryFor(userid)
    local success_encode, input_json = pcall(function()
        return json.encode({
            Token = SUB.CONSTANTS.WEB_API_TOKEN,
            KU = userid,
            Game = "DontStarveTogether"
        })
    end)

    if not success_encode then
        return SUB.error("BlacklistManager", "JSON failed to encode the input data for SFSL query!")
    end

    TheSim:QueryServer(SUB.CONSTANTS.FSLS_QUERY_URL, function(...)
        BlacklistManager.HandleFamilySharingCheckQuery(userid, ...)
    end, "POST", input_json)
end

-- -- Currently not used
-- function Blacklist:GetBannedKleiIDs()
--     local klei_ids = {}
--     for i, v in ipairs(blacklist) do
--         if not v.empty and v.userid ~= nil then
--             table.insert(klei_ids, v.userid)
--         end
--     end

--     return klei_ids
-- end

function BlacklistManager.GetDebugString()
    print("-------------------------------")
    print("\tSERVER BLACKLIST:")
    for i, v in ipairs(BlacklistManager.GetBlacklist()) do
        if not v.empty then
            print("\t"..i..". "..(v.userid or v.netid).."")
        end
    end
    print("-------------------------------")
end

-------------------------------

SUB.BlacklistManager = BlacklistManager

-------------------------------