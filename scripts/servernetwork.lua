--[[
    Mod server-side network.
--]]

local PEARL = PEARL
local Ents = Ents
local TheNet, TheInput = TheNet, TheInput

----------------------------------
-- Declaration
----------------------------------

--- @class ServerNetwork
local ServerNetwork = {}

----------------------------------
-- Public Functions
----------------------------------

-- Called from server-side user command handlers.
-- Sends a RPC to the client with the given userid.
-- Note: This works only if the player is connected to the local shard.
function ServerNetwork:SendCommandResponse(userid, message, ...)
    if not (message and userid) then
        return
    end

    return PEARL.SendRPCToClient(PEARL.RPCS.SendDirectMessage, userid, message, ...)
end

function ServerNetwork:SendUserDisconnectFor(userid, reason, ...)
    PEARL.info("ServerNetwork:SendUserDisconnectFor", userid, reason)

    PEARL.SendRPCToClient(PEARL.RPCS.Disconnect, userid, reason, ...)
    if TheWorld ~= nil then
        TheWorld:PushModEvent("clientconnectionclosed", {
            userid = userid, reason = reason
        })
    end

    -- Give a tick to the RPC queue to handle the Disconnect RPC first
    -- This makes sure that the connection is removed in case of errors.
    PEARL.Scheduler:ExecuteInTime(0, function()
        -- Kick out the connection from this user,
        -- so it doesn't block other incoming connections.
        --
        -- Note: This doesn't work for admins.
        PEARL.debug("Kicking player from the server...")
        TheNet:Kick(userid)--, PEARL.CONSTS.DISCONNECT_KICK_TIME)
    end)
end

----------------------------------
-- Network Callbacks
----------------------------------

-- Used by the engine to notify lua on the master shard
-- that a secondary shard has changed it's state. This also notifies the shard itself.
PEARL.AddGlobalFunctionPreCall("Shard_UpdateWorldState", function(world_id, state)
    if TheWorld ~= nil then
        TheWorld:PushEvent("shard_stateupdate", state)
    end
end)

-- Looks like this is pushed only on the Master shard
PEARL.AddGlobalFunctionPreCall("WorldRollbackFromSim", function(count)
    if TheWorld ~= nil then
        TheWorld:PushEvent("world_rollback", count)
    end

    PEARL.EventProcessor:HandleEvent("quit")
end)

PEARL.AddGlobalFunctionPreCall("WorldResetFromSim", function()
    if TheWorld ~= nil then
        TheWorld:PushEvent("world_reset")
    end

    PEARL.EventProcessor:HandleEvent("quit")
end)

PEARL.AddGlobalFunctionPreCall("Shutdown", function(...)
    if TheWorld ~= nil then
        TheWorld:PushEvent("shard_shutdown")
    end

    PEARL.EventProcessor:HandleEvent("quit")
end)

PEARL.OverrideGlobal("ExecuteConsoleCommand", function(fnstr, guid, x, z)
    local saved_ThePlayer
    if guid ~= nil then
        saved_ThePlayer = ThePlayer
        ThePlayer = guid ~= nil and Ents[guid] or nil
    end
    TheInput.overridepos = (x ~= nil and z ~= nil and Vector3(x, 0, z)) or nil

    local success, response = pcall(loadstring(fnstr))
    if success then
        local doer = Ents[guid]
        if doer then
            doer:PushModEvent("ms_commandexecuted", fnstr)
        end
    else
        nolineprint(response)
    end

    if guid ~= nil then
        ThePlayer = saved_ThePlayer
    end
    TheInput.overridepos = nil
end)

----------------------------------
-- World Network Events
----------------------------------

PEARL.AddWorldPostInit(function(world)
    if not world then
        return
    end

    world:SafeListenForEvent("ms_clientauthenticationcomplete", function(self, data)
        PEARL.EventProcessor:HandleEvent("ms_clientauthenticationcomplete", data.userid)
    end)
end)

----------------------------------
-- Return
----------------------------------

return ServerNetwork
