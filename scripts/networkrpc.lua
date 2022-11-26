--[[
    Here we handle all the client RPCs. Therefore, this is loaded only
    client side. So we do not have access to the SUB table here.
--]]

local PEARL = PEARL

local TheNet, ThePlayer = TheNet, ThePlayer

--------------------------
-- Initialization
--------------------------

PEARL.RPCS = {}

local CLIENT_RPCS = {
    SendDirectMessage = function(message, ...)
        if not (ThePlayer and ChatHistory and type(message) == "string") then
            return
        end

        ChatHistory:SendCommandResponse(message)
    end,

    Disconnect = function(...)
        PEARL.ClientNetwork:Disconnect(...)
    end,

    SendLocalizationRequest = function()
        PEARL.EventProcessor:HandleEvent("localization_request_received")
    end,
}

local SHARD_RPCS = {
    -- Used by the VersionChecker for shutting down secondary shards
    -- to synchronize the shutdown process on version mismatch.
    ExecuteBroadcast = function(shard_id, ...)
        return ExecuteConsoleCommand(...)
    end,
}

-- local SERVER_RPCS = {}

--- @TODO Create some kind of a persistent cache for localized clients
local SERVER_USERID_RPCS = {
    -- This is being sent when the mod is loaded on the client's side
    ClientModNetworkReady = function(userid)
        PEARL.debug("RPC: ClientModNetworkReady")

        PEARL.EventProcessor:HandleEvent("ms_clientmodnetworkready", userid)
    end,

    ClientLocalizationCompleted = function(userid, locale)
        PEARL.debug("RPC: ClientLocalizationCompleted")

        PEARL.EventProcessor:HandleEvent("ms_clientlocalizationcomplete", userid, locale)
    end,

    AFKStateChanged = function(userid, is_afk, kicked, ...)
        local player = LookupPlayerInstByUserID(userid)
        local client = TheNet:GetClientTableForUser(userid)
        if not player or client then
            return
        end

        local name = player and player:GetDisplayName() or client.name
        local entity = player and player.entity or nil
        if kicked then
            return TheNet:Announce(STRINGS.PEARL.LOGS.USER_INACTIVE_KICKED:format(
                name
            ), entity, nil, "kicked_from_game")
        end

        -- Since it's an announcement,
        -- it will be logged to discord automatically.
        TheNet:Announce((is_afk and STRINGS.PEARL.LOGS.USER_INACTIVE or STRINGS.PEARL.LOGS.USER_ACTIVE):format(
            name
        ), entity, nil, is_afk and "afk_start" or "afk_stop")
    end,
}

-- For Debug
local CLIENT_RPCS_TO_NAME = {
    [1] = "SendDirectMessage",
    [2] = "Disconnect",
    [3] = "SendLocalizationRequest",
}

-- For Debug
local SERVER_RPCS_TO_NAME = {
    [1] = "AfkStateChanged",
    [2] = "ClientModNetworkReady",
    [3] = "ClientLocalizationCompleted",
}

--------------------------
-- Helpers
--------------------------
-- Note: Handle all shard RPCs in the backend

function PEARL.GetClientRPC(name)
    return GetClientModRPC(PEARL.RPC_NAME, name)
end

function PEARL.GetShardRPC(name)
    return GetShardModRPC(PEARL.RPC_NAME, name)
end

function PEARL.GetServerRPC(name)
    return GetModRPC(PEARL.RPC_NAME, name)
end

function PEARL.SendRPCToClient(name, ...)
    PEARL.debug("Sending rpc", CLIENT_RPCS_TO_NAME[name], "to the client")
    return SendModRPCToClient(PEARL.GetClientRPC(name), ...)
end

function PEARL.SendRPCToShard(name, ...)
    return SendModRPCToShard(PEARL.GetShardRPC(name), ...)
end

function PEARL.SendRPCToServer(name, ...)
    PEARL.debug("Sending rpc", SERVER_RPCS_TO_NAME[name], "to the server")
    return SendModRPCToServer(PEARL.GetServerRPC(name), ...)
end

-- Note: All of these RPCs needs to be loaded
-- on the server and client as well.
--------------------------
-- Client RPCs
--------------------------

do
    local i = 1
    for name, cb in pairs(CLIENT_RPCS) do
        AddClientModRPCHandler(PEARL.RPC_NAME, i, cb)

        PEARL.RPCS[name] = i
        i = i + 1
    end
end

--------------------------
-- Server RPCs
--------------------------

do
    local i = 1
    -- for name, cb in pairs(SERVER_RPCS) do
    --     AddModRPCHandler(PEARL.RPC_NAME, i, cb)

    --     PEARL.RPCS[name] = i
    --     i = i + 1
    -- end

    for name, cb in pairs(SERVER_USERID_RPCS) do
        AddModRPCHandler(PEARL.RPC_NAME, i, cb)
        MarkUserIDRPC(PEARL.RPC_NAME, i)

        PEARL.RPCS[name] = i
        i = i + 1
    end
end
--------------------------
-- Shard RPCs
--------------------------

do
    local i = 0
    for name, cb in pairs(SHARD_RPCS) do
        AddShardModRPCHandler(PEARL.RPC_NAME, i, cb)

        PEARL.RPCS[name] = i
        i = i + 1
    end
end
